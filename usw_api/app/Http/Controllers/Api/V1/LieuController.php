<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Requests\Contenus\ContenusDuLieu;
use App\Http\Requests\Contenus\LieuProche;
use App\Http\Resources\ContenuResource;
use App\Http\Resources\LieuResource;
use App\Models\Lieu;
use App\Services\Lieux\PlacesGoogle;
use App\Services\Lieux\RapprocheurLieu;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

/** Les lieux (E33), ouverts aux visiteurs. */
class LieuController extends Controller
{
    private const LIEUX_ENREGISTRES_MAX = 500;

    /** GET lieux/{lieu} : le lieu et ses 4 meilleures photos. */
    public function afficher(Request $requete, Lieu $lieu): LieuResource
    {
        $moi = $requete->user('sanctum');
        // Avec ma réaction et mes enregistrements : la page d'une photo ouverte d'ici les connaît.
        $lieu->load(['ville.pays', 'meilleures' => fn ($q) => $q->limit(4)->avecMoi($moi)->with('variantes')]);
        if ($moi) {
            $lieu->setAttribute('enregistre', $moi->lieuxEnregistres()->whereKey($lieu->id)->exists());
        }

        return new LieuResource($lieu);
    }

    /** PUT moi/lieux/{lieu} : enregistrer un lieu pour y aller plus tard (500 au plus). */
    public function enregistrer(Request $requete, Lieu $lieu): Response
    {
        abort_if($lieu->slug === Lieu::SANS_LIEU, 404);
        $moi = $requete->user();
        if (! $moi->lieuxEnregistres()->whereKey($lieu->id)->exists()) {
            if ($moi->lieuxEnregistres()->count() >= self::LIEUX_ENREGISTRES_MAX) {
                throw new ErreurMetier(422, 'Vous avez déjà enregistré 500 lieux. Retirez-en un pour enregistrer celui-ci.');
            }
            $moi->lieuxEnregistres()->attach($lieu->id);
        }

        return response()->noContent();
    }

    /** DELETE moi/lieux/{lieu} */
    public function oublier(Request $requete, Lieu $lieu): Response
    {
        $requete->user()->lieuxEnregistres()->detach($lieu->id);

        return response()->noContent();
    }

    /**
     * GET moi/lieux : mes lieux enregistrés, les derniers d'abord, 30 par page (curseur). Un lieu
     * dont toutes les photos ont été supprimées sort de la liste, chez tous ceux qui l'avaient
     * enregistré : « retires » donne leurs noms, une fois, pour que l'application le dise.
     */
    public function enregistres(Request $requete): JsonResponse
    {
        $retires = DB::table('lieux_enregistres')->where('utilisateur_id', $requete->user()->id)
            ->leftJoin('lieux', 'lieux.id', '=', 'lieux_enregistres.lieu_id')
            ->where(fn ($q) => $q->whereNull('lieux.id')->orWhere('lieux.nombre_contenus', '<=', 0))
            ->get(['lieux_enregistres.id', 'lieux.slug', 'lieux.nom']);
        if ($retires->isNotEmpty()) {
            DB::table('lieux_enregistres')->whereIn('id', $retires->pluck('id'))->delete();
        }
        $page = DB::table('lieux_enregistres')->where('utilisateur_id', $requete->user()->id)
            ->orderByDesc('id')->cursorPaginate(30, ['id', 'lieu_id'], 'curseur');
        $lieux = Lieu::whereIn('id', collect($page->items())->pluck('lieu_id'))
            ->with(['ville.pays', 'meilleures' => fn ($q) => $q->limit(4)->avecMoi($requete->user())->with('variantes')])->get()->keyBy('id');
        $data = collect($page->items())->map(fn ($e) => $lieux->get($e->lieu_id))->filter()->values();

        return response()->json([
            'data' => LieuResource::collection($data)->resolve($requete),
            'retires' => $retires->map(fn ($r) => ['id' => $r->slug, 'nom' => $r->nom])->values()->all(),
            'meta' => ['next_cursor' => $page->nextCursor()?->encode()],
        ]);
    }

    /** GET lieux/{lieu}/contenus : les photos et reels publiés, les plus récents d'abord, par curseur. */
    public function contenus(ContenusDuLieu $requete, Lieu $lieu): AnonymousResourceCollection
    {
        $moi = $requete->user('sanctum');
        // Les reels filmés dans Discover sont dans les Reels, pas sur la page du lieu.
        $page = $lieu->contenus()->publies()->horsReels()->avecMoi($moi)->sansBloques($moi)
            ->when($requete->validated('type'), fn ($q, $type) => $q->where('type', $type))
            ->with(['auteur', 'capture.modele', 'variantes'])
            ->orderByDesc('publie_le')->orderByDesc('id')
            ->cursorPaginate(20, cursorName: 'curseur');

        return ContenuResource::collection($page);
    }

    /**
     * GET lieux/suggestions : en publiant, chercher le lieu par son nom. Les lieux de Discover
     * d'abord (accents et majuscules ignorés), puis ceux de Google, près de la position donnée.
     */
    public function suggestions(Request $requete, PlacesGoogle $google): JsonResponse
    {
        $v = $requete->validate([
            'q' => ['required', 'string', 'min:2', 'max:100'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ]);
        $mots = array_slice(array_filter(explode(' ', Lieu::normaliser($v['q']))), 0, 5);
        $lieux = Lieu::query()->whereNotNull('latitude')
            ->where(fn ($q) => collect($mots)->each(fn ($m) => $q->where('recherche', 'like', "%{$m}%")))
            ->with('ville.pays')->orderByDesc('nombre_contenus')->limit(5)->get();
        $lat = isset($v['latitude']) ? (float) $v['latitude'] : null;
        $lon = isset($v['longitude']) ? (float) $v['longitude'] : null;

        return response()->json([
            'lieux' => LieuResource::collection($lieux)->resolve($requete),
            'google' => $google->suggestions($v['q'], $lat, $lon),
        ]);
    }

    /** POST lieux/google : le lieu de Discover d'un lieu choisi dans les suggestions de Google. */
    public function depuisGoogle(Request $requete, PlacesGoogle $google): LieuResource
    {
        $v = $requete->validate(['id' => ['required', 'string', 'max:300']]);
        $lieu = $google->lieu($v['id']) ?? throw new ErreurMetier(404, 'Ce lieu est introuvable. Posez l’épingle sur la carte.');

        return new LieuResource($lieu->load('ville.pays'));
    }

    /** GET lieux/google/{id} : où est un lieu de Google, pour y aller sur la carte (rien n'est créé). */
    public function positionGoogle(string $id, PlacesGoogle $google): JsonResponse
    {
        $p = $google->position($id) ?? throw new ErreurMetier(404, 'Ce lieu est introuvable.');

        return response()->json(['data' => $p]);
    }

    /** GET lieux/proche : le lieu connu le plus proche d'une position, à moins de 2 km. */
    public function proche(LieuProche $requete, RapprocheurLieu $rapprocheur): JsonResponse
    {
        $r = $rapprocheur->proche((float) $requete->validated('latitude'), (float) $requete->validated('longitude'));
        if ($r === null) {
            return response()->json(['message' => __('Aucun lieu connu à moins de 2 km. Indiquez-le sur la carte.')], 404);
        }
        $r->lieu->load('ville.pays');

        return response()->json(['lieu' => new LieuResource($r->lieu), 'distance_km' => round($r->distanceKm, 2)]);
    }
}
