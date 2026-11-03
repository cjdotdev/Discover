<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Resources\CommentaireResource;
use App\Models\Blocage;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\JaimeCommentaire;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

/**
 * Lot 5 : les commentaires (E10). Un fil à un seul niveau : la réponse à une réponse se range
 * sous le même commentaire, avec « Réponse à … ». Les @mentions notifient la personne citée.
 */
class CommentaireController extends Controller
{
    private function avecMoi(Builder $q, ?Utilisateur $moi): Builder
    {
        $q->with(['auteur', 'repondA', 'contenu:id,utilisateur_id'])->visibles();
        if ($moi !== null) {
            $q->select('commentaires.*')
                ->withExists(['jaimes as aime_par_moi' => fn ($j) => $j->where('utilisateur_id', $moi->id)])
                ->whereNotIn('commentaires.utilisateur_id', Blocage::where('bloqueur_id', $moi->id)->select('bloque_id'));
        }

        return $q;
    }

    /** GET contenus/{contenu}/commentaires : l'épinglé d'abord, puis les plus récents (30 par page). */
    public function index(Request $requete, Contenu $contenu): AnonymousResourceCollection
    {
        Gate::forUser($requete->user('sanctum'))->authorize('voir', $contenu);
        $page = $this->avecMoi($contenu->commentaires()->whereNull('parent_id')->getQuery(), $requete->user('sanctum'))
            ->orderByDesc('epingle')->orderByDesc('id')
            ->cursorPaginate(30, cursorName: 'curseur');

        return CommentaireResource::collection($page);
    }

    /** GET commentaires/{commentaire}/reponses : dans l'ordre où elles ont été écrites. */
    public function reponses(Request $requete, Commentaire $commentaire): AnonymousResourceCollection
    {
        Gate::forUser($requete->user('sanctum'))->authorize('voir', $commentaire->contenu);
        $reponses = $this->avecMoi($commentaire->reponses()->getQuery(), $requete->user('sanctum'))->orderBy('id')->limit(200)->get();
        $reponses->each->setRelation('parent', $commentaire);

        return CommentaireResource::collection($reponses);
    }

    /** POST contenus/{contenu}/commentaires {texte, parent?} */
    public function creer(Request $requete, Contenu $contenu): JsonResponse
    {
        Gate::authorize('voir', $contenu);
        abort_unless($contenu->estVisible(), 404);
        $v = $requete->validate([
            'texte' => ['required', 'string', 'min:1', 'max:1000'],
            'parent' => ['nullable', 'string', 'max:30'],
        ]);
        $moi = $requete->user();
        $texte = trim(preg_replace('/\s+/u', ' ', $v['texte']));
        if ($texte === '') {
            throw new ErreurMetier(422, 'Le commentaire est vide.');
        }

        $parent = null;
        $repondA = null;
        if (! empty($v['parent'])) {
            $cible = Commentaire::where('ulid', $v['parent'])->where('contenu_id', $contenu->id)->visibles()->firstOrFail();
            // Un seul niveau : répondre à une réponse range la réponse sous le même fil.
            $parent = $cible->parent_id ? Commentaire::find($cible->parent_id) : $cible;
            $repondA = Utilisateur::find($cible->utilisateur_id);
        }

        preg_match_all('/@([a-z0-9._]{2,30})/', mb_strtolower($texte), $m);
        $mentionnes = Utilisateur::whereIn('nom_utilisateur', array_unique($m[1]))->whereNull('suppression_demandee_le')->where('id', '!=', $moi->id)->limit(10)->get();

        $c = Commentaire::create([
            'contenu_id' => $contenu->id,
            'utilisateur_id' => $moi->id,
            'parent_id' => $parent?->id,
            'repond_a_id' => $repondA?->id,
            'texte' => $texte,
            'mentions' => $mentionnes->pluck('id')->all() ?: null,
        ]);

        $auteur = Utilisateur::find($contenu->utilisateur_id);
        $deja = collect();
        if ($repondA !== null) {
            Activite::a($repondA, new Activite('reponse', 'a répondu à votre commentaire.', $moi, $contenu, $c));
            $deja->push($repondA->id);
        }
        foreach ($mentionnes as $u) {
            if (! $deja->contains($u->id)) {
                Activite::a($u, new Activite('mention', 'vous a mentionné dans un commentaire.', $moi, $contenu, $c));
                $deja->push($u->id);
            }
        }
        if ($auteur !== null && ! $deja->contains($auteur->id)) {
            Activite::a($auteur, new Activite('commentaire', 'a commenté votre publication.', $moi, $contenu, $c));
        }

        $c->load(['auteur', 'repondA', 'contenu:id,utilisateur_id', 'parent']);
        $c->setAttribute('aime_par_moi', false);

        return (new CommentaireResource($c))->response()->setStatusCode(201);
    }

    /** PATCH commentaires/{commentaire} {texte} : son auteur seul. */
    public function modifier(Request $requete, Commentaire $commentaire): CommentaireResource
    {
        abort_unless($requete->user()->id === $commentaire->utilisateur_id, 404);
        // Comme une publication : modifiable pendant 1 h, ensuite il ne peut que se supprimer.
        if ($commentaire->created_at?->lt(now()->subMinutes(Contenu::DELAI_MODIFICATION_MINUTES))) {
            throw new ErreurMetier(422, 'Un commentaire ne se modifie plus après 1 h. Vous pouvez le supprimer.');
        }
        $texte = trim(preg_replace('/\s+/u', ' ', $requete->validate(['texte' => ['required', 'string', 'min:1', 'max:1000']])['texte']));
        $commentaire->update(['texte' => $texte]);
        $commentaire->load(['auteur', 'repondA', 'contenu:id,utilisateur_id']);

        return new CommentaireResource($commentaire);
    }

    /** DELETE commentaires/{commentaire} : son auteur, ou l'auteur de la publication. Ses réponses partent avec lui. */
    public function supprimer(Request $requete, Commentaire $commentaire): Response
    {
        $contenu = Contenu::find($commentaire->contenu_id);
        $moi = $requete->user();
        abort_unless($moi->id === $commentaire->utilisateur_id || $moi->id === $contenu?->utilisateur_id, 404);
        $commentaire->reponses()->get()->each->delete();
        $commentaire->delete();

        return response()->noContent();
    }

    /** POST commentaires/{commentaire}/epingle : l'auteur de la publication épingle (ou détache) un commentaire. */
    public function epingler(Request $requete, Commentaire $commentaire): JsonResponse
    {
        $contenu = Contenu::findOrFail($commentaire->contenu_id);
        abort_unless($requete->user()->id === $contenu->utilisateur_id, 404);
        if ($commentaire->parent_id !== null) {
            throw new ErreurMetier(422, 'Seul un commentaire, pas une réponse, peut être épinglé.');
        }
        $epingle = ! $commentaire->epingle;
        // Un seul épinglé par publication.
        Commentaire::where('contenu_id', $contenu->id)->where('epingle', true)->update(['epingle' => false]);
        $commentaire->update(['epingle' => $epingle]);

        return response()->json(['epingle' => $epingle]);
    }

    /** PUT commentaires/{commentaire}/jaime */
    public function aimer(Request $requete, Commentaire $commentaire): JsonResponse
    {
        Gate::authorize('voir', Contenu::findOrFail($commentaire->contenu_id));
        JaimeCommentaire::firstOrCreate(['utilisateur_id' => $requete->user()->id, 'commentaire_id' => $commentaire->id]);

        return response()->json(['jaime' => true, 'total' => $commentaire->refresh()->nombre_jaime]);
    }

    /** DELETE commentaires/{commentaire}/jaime */
    public function nePlusAimer(Request $requete, Commentaire $commentaire): JsonResponse
    {
        JaimeCommentaire::where('utilisateur_id', $requete->user()->id)->where('commentaire_id', $commentaire->id)->first()?->delete();

        return response()->json(['jaime' => false, 'total' => $commentaire->refresh()->nombre_jaime]);
    }
}
