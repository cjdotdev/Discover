<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Resources\AuteurResource;
use App\Models\Abonnement;
use App\Models\Blocage;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\Reaction;
use App\Models\Signalement;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use App\Support\Spectateur;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

/**
 * Lot 5 : réagir (E06), suivre un créateur (E20), partager (E07), bloquer et signaler (E22).
 * Tout se fait sur des contenus publiés ; un brouillon d'un autre n'existe pas (404).
 */
class CommunauteController extends Controller
{
    private function membre(string $nom): Utilisateur
    {
        return Utilisateur::where('nom_utilisateur', mb_strtolower(ltrim($nom, '@')))->whereNull('suppression_demandee_le')->firstOrFail();
    }

    private function publie(Request $requete, Contenu $contenu): void
    {
        Gate::forUser($requete->user('sanctum'))->authorize('voir', $contenu);
        abort_unless($contenu->estVisible(), 404);
    }

    // ------------------------------------------------------------ réactions

    /** PUT contenus/{contenu}/reaction : la réaction du membre (une seule ; la changer la remplace). */
    public function reagir(Request $requete, Contenu $contenu): JsonResponse
    {
        $this->publie($requete, $contenu);
        $type = $requete->validate(['type' => ['required', Rule::in(array_keys(Reaction::TYPES))]])['type'];
        $r = Reaction::updateOrCreate(['utilisateur_id' => $requete->user()->id, 'contenu_id' => $contenu->id], ['type' => $type]);
        // Retirée puis remise : une seule notification par jour.
        if ($r->wasRecentlyCreated && Cache::add('notif:reaction:'.$requete->user()->id.':'.$contenu->id, 1, now()->addDay())) {
            Activite::a($contenu->auteur, new Activite('reaction', 'a réagi :emoji à votre publication.', $requete->user(), $contenu, valeurs: ['emoji' => Reaction::TYPES[$type]]));
        }

        return response()->json(['reaction' => $type, 'reactions' => $contenu->refresh()->nombre_reactions]);
    }

    /** DELETE contenus/{contenu}/reaction */
    public function retirerReaction(Request $requete, Contenu $contenu): JsonResponse
    {
        $this->publie($requete, $contenu);
        Reaction::where('utilisateur_id', $requete->user()->id)->where('contenu_id', $contenu->id)->first()?->delete();

        return response()->json(['reaction' => null, 'reactions' => $contenu->refresh()->nombre_reactions]);
    }

    /** GET contenus/{contenu}/reactions?type=coeur : qui a réagi, et le total de chaque réaction. */
    public function reactions(Request $requete, Contenu $contenu): JsonResponse
    {
        $this->publie($requete, $contenu);
        $type = $requete->validate(['type' => ['nullable', Rule::in(array_keys(Reaction::TYPES))]])['type'] ?? null;
        $moi = $requete->user('sanctum');
        $totaux = Reaction::where('contenu_id', $contenu->id)->selectRaw('type, count(*) as n')->groupBy('type')->pluck('n', 'type');
        $page = Reaction::where('contenu_id', $contenu->id)
            ->when($type, fn ($q) => $q->where('type', $type))
            ->with('utilisateur')->latest('id')->cursorPaginate(30, cursorName: 'curseur');
        $suivis = $moi === null ? collect() : Abonnement::where('abonne_id', $moi->id)
            ->whereIn('createur_id', $page->getCollection()->pluck('utilisateur_id'))->pluck('createur_id')->flip();

        return response()->json([
            'totaux' => (object) $totaux->map(fn ($n) => (int) $n)->all(),
            'total' => (int) $totaux->sum(),
            'data' => $page->getCollection()->map(fn (Reaction $r) => [
                'type' => $r->type,
                'membre' => (new AuteurResource($r->utilisateur))->resolve($requete),
                'abonne' => $suivis->has($r->utilisateur_id),
            ])->all(),
            'meta' => ['next_cursor' => $page->nextCursor()?->encode()],
        ]);
    }

    // ------------------------------------------------------------ partager

    /** POST contenus/{contenu}/partage : un partage de plus (le lien part par WhatsApp, etc.). */
    public function partager(Request $requete, Contenu $contenu): JsonResponse
    {
        $this->publie($requete, $contenu);
        if (Cache::add('partage:'.$contenu->id.':'.Spectateur::de($requete).':'.today()->toDateString(), 1, now()->endOfDay())) {
            $contenu->increment('nombre_partages');
        }

        return response()->json(['partages' => $contenu->nombre_partages]);
    }

    // ------------------------------------------------------------ s'abonner, bloquer

    /** PUT utilisateurs/{nom}/abonnement */
    public function sAbonner(Request $requete, string $nom): JsonResponse
    {
        $createur = $this->membre($nom);
        $moi = $requete->user();
        if ($createur->id === $moi->id) {
            throw new ErreurMetier(422, 'Vous ne pouvez pas vous abonner à vous-même.');
        }
        if ($createur->aBloque($moi) || $moi->aBloque($createur)) {
            throw new ErreurMetier(422, 'Vous ne pouvez pas suivre ce compte.');
        }
        $a = Abonnement::firstOrCreate(['abonne_id' => $moi->id, 'createur_id' => $createur->id]);
        if ($a->wasRecentlyCreated && Cache::add('notif:abonne:'.$moi->id.':'.$createur->id, 1, now()->addDay())) {
            Activite::a($createur, new Activite('abonne', 's’est abonné à vous.', $moi));
        }

        return response()->json(['abonne' => true, 'abonnes' => $createur->refresh()->nombre_abonnes, 'mes_abonnements' => $requete->user()->refresh()->nombre_abonnements]);
    }

    /** DELETE utilisateurs/{nom}/abonnement */
    public function seDesabonner(Request $requete, string $nom): JsonResponse
    {
        $createur = $this->membre($nom);
        Abonnement::where('abonne_id', $requete->user()->id)->where('createur_id', $createur->id)->first()?->delete();

        return response()->json(['abonne' => false, 'abonnes' => $createur->refresh()->nombre_abonnes, 'mes_abonnements' => $requete->user()->refresh()->nombre_abonnements]);
    }

    /** GET moi/abonnements : les créateurs que je suis. */
    public function mesAbonnements(Request $requete): JsonResponse
    {
        $ids = Abonnement::where('abonne_id', $requete->user()->id)->latest('id')->pluck('createur_id');
        $membres = Utilisateur::whereIn('id', $ids)->get()->sortBy(fn ($u) => $ids->search($u->id))->values();

        return response()->json(['data' => AuteurResource::collection($membres)->resolve($requete)]);
    }

    /** PUT utilisateurs/{nom}/blocage : ni ses publications, ni ses commentaires, ni ses notifications ; les abonnements tombent. */
    public function bloquer(Request $requete, string $nom): JsonResponse
    {
        $autre = $this->membre($nom);
        $moi = $requete->user();
        if ($autre->id === $moi->id) {
            throw new ErreurMetier(422, 'Vous ne pouvez pas vous bloquer vous-même.');
        }
        Blocage::firstOrCreate(['bloqueur_id' => $moi->id, 'bloque_id' => $autre->id]);
        Abonnement::where(fn ($q) => $q->where('abonne_id', $moi->id)->where('createur_id', $autre->id))
            ->orWhere(fn ($q) => $q->where('abonne_id', $autre->id)->where('createur_id', $moi->id))
            ->get()->each->delete();

        return response()->json(['bloque' => true, 'message' => __(':nom est bloqué : vous ne verrez plus ses publications.', ['nom' => $autre->nom_affiche ?? $autre->nom_utilisateur])]);
    }

    /** GET moi/blocages : les comptes que j'ai bloqués (ils ne le savent pas). */
    public function mesBlocages(Request $requete): JsonResponse
    {
        $ids = Blocage::where('bloqueur_id', $requete->user()->id)->latest('id')->pluck('bloque_id');
        $membres = Utilisateur::whereIn('id', $ids)->get()->sortBy(fn ($u) => $ids->search($u->id))->values();

        return response()->json(['data' => AuteurResource::collection($membres)->resolve($requete)]);
    }

    /** DELETE utilisateurs/{nom}/blocage */
    public function debloquer(Request $requete, string $nom): JsonResponse
    {
        $autre = $this->membre($nom);
        Blocage::where('bloqueur_id', $requete->user()->id)->where('bloque_id', $autre->id)->delete();

        return response()->json(['bloque' => false]);
    }

    // ------------------------------------------------------------ signaler

    /**
     * POST signalements : une photo, un reel, un profil ou un commentaire. Une seule fois par
     * membre et par cible ; la personne visée ne sait jamais qui l'a fait.
     */
    public function signaler(Request $requete): JsonResponse
    {
        $v = $requete->validate([
            'cible' => ['required', Rule::in(['contenu', 'utilisateur', 'commentaire'])],
            'id' => ['required', 'string', 'max:60'],
            'motif' => ['required', 'string', 'max:80'],
            'precision' => ['nullable', 'string', 'max:500'],
        ]);
        $cible = match ($v['cible']) {
            'contenu' => Contenu::where('ulid', $v['id'])->firstOrFail(),
            'utilisateur' => $this->membre($v['id']),
            'commentaire' => Commentaire::where('ulid', $v['id'])->firstOrFail(),
        };
        if ($cible instanceof Contenu) {
            $this->publie($requete, $cible);
        }
        Signalement::firstOrCreate(
            ['utilisateur_id' => $requete->user()->id, 'cible_type' => $v['cible'], 'cible_id' => $cible->id],
            ['motif' => $v['motif'], 'precision' => $v['precision'] ?? null],
        );

        return response()->json(['message' => __('Merci. L’équipe regarde votre signalement sous 24 h. La personne visée ne saura pas qui l’a fait.')], 201);
    }
}
