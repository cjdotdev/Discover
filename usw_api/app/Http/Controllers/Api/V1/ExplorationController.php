<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Exploration\Chercher;
use App\Http\Requests\Exploration\FilDesReels;
use App\Http\Requests\Exploration\FluxDecouverte;
use App\Http\Requests\Exploration\PresDeMoi;
use App\Http\Requests\Exploration\ZoneDeCarte;
use App\Http\Resources\AuteurResource;
use App\Http\Resources\ContenuResource;
use App\Http\Resources\LieuResource;
use App\Models\Abonnement;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Utilisateur;
use App\Services\Contenus\Recommandation;
use App\Support\Geo;
use App\Support\MaPart;
use App\Support\Spectateur;
use App\Support\Themes;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

/**
 * Lot 4 : explorer (E03, E04, E06, E11, E31), ouvert aux visiteurs. Les lieux arrivent avec
 * leur pile (les 4 meilleures photos), chargée d'avance : pas de requête par lieu.
 */
class ExplorationController extends Controller
{
    /** Le rayon de « Près de moi » quand l'application n'en donne pas, en km. */
    public const RAYON_KM = 60;

    /** La version des pages mises en cache : un contenu publié ou retiré la change. */
    public static function versionDuFlux(): int
    {
        return (int) Cache::get('flux:version', 0);
    }

    public static function fluxChange(): void
    {
        Cache::forever('flux:version', self::versionDuFlux() + 1);
    }

    /** Les lieux qui ont au moins une photo publiée, avec leur pile, leur ville et leur pays. */
    private function lieux(array $types): Builder
    {
        // Un lieu qui n'a que des reels filmés dans Discover n'a pas de pile : ils sont dans les Reels.
        return Lieu::query()
            ->whereColumn('nombre_contenus', '>', 'nombre_reels')
            ->when($types, fn ($q) => $q->whereIn('type', $types))
            ->with(['ville.pays', 'meilleures' => fn ($q) => $q->limit(4)->with('variantes')]);
    }

    /**
     * GET flux/decouverte : l'accueil en piles, les lieux les mieux notés d'abord (Recommandation), 20 par page
     * (curseur). Chaque page est gardée 60 secondes (ARCHITECTURE.md, 6.4).
     */
    public function decouverte(FluxDecouverte $requete): JsonResponse
    {
        $types = $requete->types();
        $cle = 'flux:decouverte:'.self::versionDuFlux().':'.md5(json_encode([$requete->validated('curseur'), $types]));
        $donnees = Cache::remember($cle, 60, function () use ($types, $requete) {
            $page = LieuResource::collection(
                $this->lieux($types)->where('slug', '!=', Lieu::SANS_LIEU)
                    ->orderByDesc('score')->orderByDesc('nombre_contenus')->orderByDesc('id')->cursorPaginate(20, cursorName: 'curseur')
            )->response()->getData(true);
            // La pile « Sans lieu » vient après tous les lieux, en bas de l'accueil.
            if (($page['meta']['next_cursor'] ?? null) === null && ! $types) {
                $sansLieu = $this->lieux([])->where('slug', Lieu::SANS_LIEU)->first();
                if ($sansLieu !== null) {
                    $page['data'][] = (new LieuResource($sansLieu))->resolve($requete);
                }
            }

            return $page;
        });
        // La page est la même pour tous ; ma réaction et mes enregistrements s'y ajoutent ensuite.
        $donnees['data'] = MaPart::dansLesLieux($donnees['data'] ?? [], $requete->user('sanctum'));

        return response()->json($donnees);
    }

    /** GET flux/pres-de-moi : les lieux autour de la position, du plus proche au plus loin (40 au plus). */
    public function presDeMoi(PresDeMoi $requete): JsonResponse
    {
        $lat = (float) $requete->validated('latitude');
        $lon = (float) $requete->validated('longitude');
        $rayon = (float) ($requete->validated('rayon') ?? self::RAYON_KM);
        [$latMin, $latMax, $lonMin, $lonMax] = Geo::rectangle($lat, $lon, $rayon);

        $lieux = $this->lieux($requete->types())
            ->whereBetween('latitude', [$latMin, $latMax])
            ->whereBetween('longitude', [$lonMin, $lonMax])
            ->limit(400)->get()
            ->map(fn (Lieu $l) => [$l, Geo::distanceKm($lat, $lon, $l->latitude, $l->longitude)])
            ->filter(fn ($p) => $p[1] <= $rayon)
            ->sortBy(fn ($p) => $p[1])
            ->take(40)
            ->values();

        return response()->json([
            'data' => MaPart::dansLesLieux($lieux->map(fn ($p) => [...(new LieuResource($p[0]))->resolve($requete), 'distance_km' => round($p[1], 1)])->all(), $requete->user('sanctum')),
            'rayon_km' => $rayon,
        ]);
    }

    /**
     * GET reels : « Pour toi » (Recommandation), 10 par page ; ou ceux des créateurs suivis, ou
     * ceux d'autour d'une position, les plus récents d'abord.
     */
    public function reels(FilDesReels $requete, Recommandation $reco): AnonymousResourceCollection|JsonResponse
    {
        $moi = $requete->user('sanctum');
        if (! $requete->boolean('abonnements') && ! $requete->filled('latitude')) {
            return $this->pourToi($requete, $reco, $moi);
        }
        $q = Contenu::publies()->reels()
            ->with(['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes', 'musique'])
            ->avecMoi($moi)->sansBloques($moi);
        // Abonnements : les reels des créateurs que l'on suit.
        if ($requete->boolean('abonnements')) {
            abort_if($moi === null, 401, 'Connectez-vous pour continuer.');
            $q->whereIn('contenus.utilisateur_id', Abonnement::where('abonne_id', $moi->id)->select('createur_id'));
        }
        if ($requete->filled('latitude')) {
            [$latMin, $latMax, $lonMin, $lonMax] = Geo::rectangle(
                (float) $requete->validated('latitude'),
                (float) $requete->validated('longitude'),
                (float) ($requete->validated('rayon') ?? self::RAYON_KM),
            );
            $q->whereHas('lieu', fn ($l) => $l->whereBetween('latitude', [$latMin, $latMax])->whereBetween('longitude', [$lonMin, $lonMax]));
        }

        return ContenuResource::collection($q->orderByDesc('publie_le')->orderByDesc('id')->cursorPaginate(10, cursorName: 'curseur'));
    }

    /** Les reels « Pour toi » : l'ordre de la recommandation, par pages de 10 (le curseur est un rang). */
    private function pourToi(FilDesReels $requete, Recommandation $reco, ?Utilisateur $moi): JsonResponse
    {
        $curseur = (string) ($requete->validated('curseur') ?? '');
        $debut = ctype_digit($curseur) ? (int) $curseur : 0;
        // La première page refait l'ordre (tirer pour actualiser) ; les suivantes le reprennent.
        $ordre = $reco->reels($moi, Spectateur::de($requete), refaire: $debut === 0);
        $ids = array_slice($ordre, $debut, 10);
        $contenus = Contenu::query()->whereIn('contenus.id', $ids)
            ->with(['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes', 'musique'])
            ->avecMoi($moi)->get()
            ->sortBy(fn (Contenu $c) => array_search($c->id, $ids, true))->values();
        $suite = $debut + 10 < count($ordre) ? (string) ($debut + 10) : null;

        return response()->json([
            'data' => ContenuResource::collection($contenus)->resolve($requete),
            'meta' => ['per_page' => 10, 'next_cursor' => $suite, 'prev_cursor' => null],
        ]);
    }

    /** GET carte : les lieux de la zone à l'écran, chacun avec sa photo de tête (300 au plus). */
    public function carte(ZoneDeCarte $requete): AnonymousResourceCollection
    {
        $v = $requete->validated();
        $lieux = Lieu::query()
            ->where('nombre_contenus', '>', 0)
            ->when($requete->types(), fn ($q, $types) => $q->whereIn('type', $types))
            ->whereBetween('latitude', [(float) $v['sud'], (float) $v['nord']])
            // Une zone à cheval sur l'antiméridien : l'ouest est plus grand que l'est.
            ->when(
                (float) $v['ouest'] <= (float) $v['est'],
                fn ($q) => $q->whereBetween('longitude', [(float) $v['ouest'], (float) $v['est']]),
                fn ($q) => $q->where(fn ($w) => $w->where('longitude', '>=', (float) $v['ouest'])->orWhere('longitude', '<=', (float) $v['est'])),
            )
            ->with(['ville.pays', 'meilleures' => fn ($q) => $q->limit(1)->with('variantes'), 'vitrine' => fn ($q) => $q->limit(1)->with('variantes')])
            ->orderByDesc('nombre_contenus')->limit(300)->get();
        // Un lieu qui n'a que des reels se montre avec l'affiche du meilleur.
        foreach ($lieux as $l) {
            if ($l->meilleures->isEmpty()) {
                $l->setRelation('meilleures', $l->vitrine);
            }
        }

        return LieuResource::collection($lieux);
    }

    /**
     * GET recherche : des lieux (par leur nom ou leur ville, accents et majuscules ignorés) et des
     * créateurs (par leur nom d'utilisateur ou leur nom affiché). 10 de chaque au plus.
     */
    public function recherche(Chercher $requete): JsonResponse
    {
        $brut = trim((string) $requete->validated('q'));
        // Les jokers de LIKE (%, _) ne passent pas, et 5 mots au plus : une recherche reste légère.
        $brut = implode(' ', array_slice(preg_split('/\s+/', trim(str_replace(['%', '_', '\\'], ' ', $brut))) ?: [], 0, 5));
        $mots = array_filter(explode(' ', Lieu::normaliser($brut)));
        $bas = mb_strtolower($brut);
        $pseudo = Str::lower(Str::ascii(ltrim($brut, '@')));

        // Chaque mot doit se trouver dans le nom, la ville ou la région (« popo mono »).
        $lieux = $mots === [] ? collect() : Lieu::query()
            ->whereColumn('nombre_contenus', '>', 'nombre_reels')
            ->where(function ($q) use ($mots) {
                foreach ($mots as $m) {
                    $q->where('recherche', 'like', "%{$m}%");
                }
            })
            ->with(['ville.pays', 'meilleures' => fn ($q) => $q->limit(4)->with('variantes')])
            ->orderByDesc('nombre_contenus')->limit(10)->get();

        $createurs = Utilisateur::query()
            ->whereNull('suppression_demandee_le')
            ->whereNotNull('nom_utilisateur')
            ->where(fn ($q) => $q->where('nom_utilisateur', 'like', "%{$pseudo}%")->orWhereRaw('lower(nom_affiche) like ?', ["%{$bas}%"]))
            ->whereHas('contenus', fn ($c) => $c->publies())
            ->withCount(['contenus as nombre_publies' => fn ($c) => $c->publies()])
            ->orderByDesc('nombre_publies')->limit(10)->get();

        // Les publications : chaque mot dans le titre, la légende, le lieu (« coucher ouidah »), ou
        // sur la photo elle-même (« arbre » : les photos où le téléphone a vu des arbres).
        $moi = $requete->user('sanctum');
        $contenus = collect();
        $bruts = array_filter(explode(' ', $bas), fn ($b) => Lieu::normaliser($b) !== '');
        if ($bruts !== []) {
            $contenus = Contenu::publies()->horsReels()
                ->where(function ($q) use ($bruts) {
                    foreach ($bruts as $b) {
                        $n = Lieu::normaliser($b);
                        $vu = Themes::etiquettesPour($b);
                        // Ce que l'IA a vu, en mots entiers, au singulier comme au pluriel.
                        $racine = preg_replace('/(?<=..)[sx]$/', '', $n);
                        $formes = array_unique([$n, $racine, $racine.'s', $racine.'x']);
                        $q->where(fn ($w) => $w->whereRaw('lower(legende) like ?', ["%{$b}%"])
                            ->orWhere(function ($ia) use ($formes) {
                                foreach ($formes as $f) {
                                    $ia->orWhere('recherche_ia', 'like', "% {$f} %");
                                }
                            })
                            ->orWhereRaw('lower(titre) like ?', ["%{$b}%"])
                            ->orWhereHas('lieu', fn ($l) => $l->where('recherche', 'like', "%{$n}%"))
                            ->when($vu !== [], fn ($w) => $w->orWhereHas('etiquettes', fn ($e) => $e->whereIn('nom', $vu)->where('confiance', '>=', Themes::CONFIANCE))));
                    }
                })
                ->with(['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes'])
                ->avecMoi($moi)->sansBloques($moi)
                ->orderByDesc('publie_le')->limit(20)->get();
        }

        return response()->json([
            'lieux' => LieuResource::collection($lieux)->resolve($requete),
            'contenus' => ContenuResource::collection($contenus)->resolve($requete),
            'createurs' => $createurs->map(fn (Utilisateur $u) => [...(new AuteurResource($u))->resolve($requete), 'nombre_contenus' => $u->nombre_publies])->all(),
        ]);
    }
}
