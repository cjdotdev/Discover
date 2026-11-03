<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ContenuResource;
use App\Http\Resources\SonResource;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Son;
use App\Models\Utilisateur;
use App\Services\Sons\Preparation;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Throwable;

/**
 * Les sons à mettre sur un reel, comme sur TikTok, Instagram, Snapchat ou WhatsApp : le
 * catalogue (les plus utilisés d'abord, par ambiance, par recherche), mes favoris, et la page
 * d'un son avec les reels qui l'utilisent.
 */
class SonController extends Controller
{
    /**
     * GET sons : le catalogue, 30 par page (curseur). `categorie=favoris` : mes favoris ;
     * `categorie=miens` : les sons que j'ai importés. Le son importé par un autre membre n'y est
     * qu'une fois qu'un reel l'a en ligne.
     */
    public function index(Request $requete): JsonResponse
    {
        $v = $requete->validate([
            'q' => ['nullable', 'string', 'min:2', 'max:100'],
            'categorie' => ['nullable', Rule::in([...Son::CATEGORIES, 'favoris', 'miens'])],
        ]);
        $moi = $requete->user('sanctum');
        $q = Son::actifs();
        if (in_array($v['categorie'] ?? null, ['favoris', 'miens'], true)) {
            abort_if($moi === null, 401, 'Connectez-vous pour continuer.');
            $v['categorie'] === 'favoris' ? $q->whereIn('id', $moi->sonsFavoris()->select('sons.id')) : $q->where('utilisateur_id', $moi->id);
        } else {
            if (isset($v['categorie'])) {
                $q->where('categorie', $v['categorie']);
            }
            $q->where(fn ($w) => $w->whereNull('utilisateur_id')->orWhere('nombre_reels', '>', 0)
                ->when($moi !== null, fn ($m) => $m->orWhere('utilisateur_id', $moi->id)));
        }
        if (isset($v['q'])) {
            foreach (array_slice(array_filter(explode(' ', Lieu::normaliser($v['q']))), 0, 5) as $mot) {
                $q->where('recherche', 'like', "%{$mot}%");
            }
        }
        $page = $this->avecFavori($q, $moi)->orderByDesc('nombre_reels')->orderBy('id')->cursorPaginate(30, cursorName: 'curseur');

        return response()->json([
            'data' => SonResource::collection($page->items())->resolve($requete),
            'categories' => Son::CATEGORIES,
            'meta' => ['next_cursor' => $page->nextCursor()?->encode()],
        ]);
    }

    /**
     * POST sons (fichier, titre) : un son importé par le membre, le son d'une vidéo ou un fichier
     * du téléphone (20 Mo, 10 minutes au plus). Il le choisit aussitôt pour son reel ; les autres
     * le trouvent une fois ce reel en ligne. Ce qu'il importe, il en répond (les droits).
     */
    public function importer(Request $requete): JsonResponse
    {
        $v = $requete->validate([
            'fichier' => ['required', 'file', 'max:20480'],
            'titre' => ['nullable', 'string', 'max:80'],
        ]);
        abort_unless(Preparation::disponible(), 503, __('Impossible d’importer un son pour le moment. Réessayez plus tard.'));
        $moi = $requete->user();
        $preparation = Preparation::creer();
        $dossier = Preparation::dossier();
        $nom = Str::random(24);
        $brut = $requete->file('fichier')->move($dossier, $nom.'.source')->getPathname();
        $sortie = "{$dossier}/{$nom}.m4a";
        try {
            try {
                $infos = $preparation->convertir($brut, $sortie);
            } catch (Throwable) {
                abort(422, __('Ce fichier ne contient pas de son lisible. Essayez un autre fichier.'));
            }
            abort_if($infos['duree_ms'] < 1000 || $infos['duree_ms'] > 600_000, 422, __('Le son doit durer entre 1 seconde et 10 minutes.'));
            $titre = trim((string) ($v['titre'] ?? '')) ?: 'Son original';
            $son = new Son([
                'cle' => 'membre:'.Str::ulid(),
                'titre' => mb_substr($titre, 0, 80),
                'artiste' => $moi->nom_affiche ?: '@'.$moi->nom_utilisateur,
                'categorie' => Son::MEMBRES,
                'duree_ms' => $infos['duree_ms'],
                'chemin' => '',
                'forme' => $infos['forme'],
                'debut_conseille_ms' => $infos['debut_ms'],
                'licence' => 'Importé par un membre',
                'attribution' => "Son importé par @{$moi->nom_utilisateur}",
                'utilisateur_id' => $moi->id,
            ]);
            $preparation->publier($son, $sortie);
        } finally {
            @unlink($brut);
            @unlink($sortie);
        }

        return response()->json(['data' => (new SonResource($son->refresh()))->resolve($requete)], 201);
    }

    /** POST sons/{son}/signaler : un son importé qui pose problème (droits, contenu). 3 signalements : retiré. */
    public function signaler(Request $requete, Son $son): Response
    {
        abort_if($son->utilisateur_id === null, 422, __('Les sons du catalogue de Discover ne peuvent pas être signalés.'));
        $moi = $requete->user();
        if ($son->utilisateur_id !== $moi->id) {
            DB::table('sons_signalements')->insertOrIgnore(['son_id' => $son->id, 'utilisateur_id' => $moi->id, 'created_at' => now()]);
            $n = DB::table('sons_signalements')->where('son_id', $son->id)->count();
            $son->forceFill(['signalements' => $n, 'actif' => $son->actif && $n < Son::SIGNALEMENTS_MAX])->save();
        }

        return response()->noContent();
    }

    /** GET sons/{son} : le son et les premiers reels qui l'utilisent. */
    public function afficher(Request $requete, Son $son): JsonResponse
    {
        $moi = $requete->user('sanctum');
        $son = $this->avecFavori(Son::whereKey($son->id), $moi)->firstOrFail();

        return response()->json(['data' => (new SonResource($son))->resolve($requete)]);
    }

    /** GET sons/{son}/reels : les reels en ligne qui l'utilisent, les plus aimés d'abord. */
    public function reels(Request $requete, Son $son): AnonymousResourceCollection
    {
        $moi = $requete->user('sanctum');

        return ContenuResource::collection(
            Contenu::publies()->where('son_id', $son->id)->avecMoi($moi)->sansBloques($moi)
                ->with(['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes', 'musique'])
                ->orderByDesc('nombre_reactions')->orderByDesc('id')
                ->cursorPaginate(18, cursorName: 'curseur')
        );
    }

    /** PUT moi/sons/{son} : le garder pour un prochain reel. */
    public function garder(Request $requete, Son $son): Response
    {
        $requete->user()->sonsFavoris()->syncWithoutDetaching([$son->id]);

        return response()->noContent();
    }

    /** DELETE moi/sons/{son} */
    public function oublier(Request $requete, Son $son): Response
    {
        $requete->user()->sonsFavoris()->detach($son->id);

        return response()->noContent();
    }

    /** @param Builder<Son> $q */
    private function avecFavori(Builder $q, ?Utilisateur $moi): Builder
    {
        return $moi === null ? $q : $q->select('sons.*')->selectRaw(
            'exists(select 1 from sons_favoris f where f.son_id = sons.id and f.utilisateur_id = ?) as favori',
            [$moi->id]
        );
    }
}
