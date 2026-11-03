<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Resources\ContenuResource;
use App\Models\Collection;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Services\Contenus\Compteurs;
use App\Support\Medias;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

/**
 * Lot 5 : les collections (E09, E19). Une collection secrète ne se voit que de son auteur ; pour
 * les autres, elle n'existe pas (404).
 */
class CollectionController extends Controller
{
    /** Une collection, avec les 4 photos de sa couverture (une requête pour toutes). */
    private function enJson(iterable $collections): array
    {
        $ids = collect($collections)->pluck('id');
        $couvertures = DB::table('enregistrements')
            ->join('variantes', fn ($j) => $j->on('variantes.contenu_id', '=', 'enregistrements.contenu_id')->whereIn('variantes.usage', ['480', 'affiche']))
            ->whereIn('enregistrements.collection_id', $ids)
            ->whereIn('enregistrements.contenu_id', Contenu::publies()->select('id'))
            ->orderByDesc('enregistrements.id')
            ->get(['enregistrements.collection_id', 'variantes.chemin'])
            ->groupBy('collection_id');

        return collect($collections)->map(fn (Collection $c) => [
            'id' => $c->ulid,
            'nom' => $c->nom,
            'secrete' => $c->secrete,
            'nombre_contenus' => $c->nombre_contenus,
            'couverture' => ($couvertures[$c->id] ?? collect())->take(4)->map(fn ($v) => Medias::public()->url($v->chemin))->values()->all(),
        ])->values()->all();
    }

    private function voir(Request $requete, Collection $collection): void
    {
        abort_if($collection->secrete && $requete->user('sanctum')?->id !== $collection->utilisateur_id, 404);
    }

    private function mienne(Request $requete, Collection $collection): void
    {
        abort_unless($requete->user()->id === $collection->utilisateur_id, 404);
    }

    /** GET collections : les miennes, la plus récemment remplie d'abord. */
    public function index(Request $requete): JsonResponse
    {
        return response()->json(['data' => $this->enJson($requete->user()->collections()->latest('updated_at')->latest('id')->get())]);
    }

    /** GET utilisateurs/{nom}/collections : celles qu'un créateur montre (pas les secrètes). */
    public function duMembre(Request $requete, string $nom): JsonResponse
    {
        $u = Utilisateur::where('nom_utilisateur', mb_strtolower(ltrim($nom, '@')))->whereNull('suppression_demandee_le')->whereNull('suspendu_le')->firstOrFail();
        $q = $u->collections()->latest('updated_at');
        if ($requete->user('sanctum')?->id !== $u->id) {
            $q->where('secrete', false);
        }

        return response()->json(['data' => $this->enJson($q->get())]);
    }

    /** POST collections {nom, secrete} */
    public function creer(Request $requete): JsonResponse
    {
        $v = $requete->validate(['nom' => ['required', 'string', 'min:1', 'max:60'], 'secrete' => ['boolean']]);
        $nom = trim($v['nom']);
        if ($requete->user()->collections()->count() >= 200) {
            throw new ErreurMetier(422, 'Vous avez atteint 200 collections. Supprimez-en une pour en créer une autre.');
        }
        if ($requete->user()->collections()->where('nom', $nom)->exists()) {
            throw new ErreurMetier(422, __('Vous avez déjà une collection « :nom ».', ['nom' => $nom]));
        }
        $c = $requete->user()->collections()->create(['nom' => $nom, 'secrete' => $v['secrete'] ?? false]);

        return response()->json(['data' => $this->enJson([$c->refresh()])[0]], 201);
    }

    /** PATCH collections/{collection} {nom?, secrete?} */
    public function modifier(Request $requete, Collection $collection): JsonResponse
    {
        $this->mienne($requete, $collection);
        $v = $requete->validate([
            'nom' => ['sometimes', 'string', 'min:1', 'max:60', Rule::unique('collections', 'nom')->where('utilisateur_id', $collection->utilisateur_id)->ignore($collection->id)],
            'secrete' => ['sometimes', 'boolean'],
        ], ['nom.unique' => 'Vous avez déjà une collection de ce nom.']);
        $collection->update($v);

        return response()->json(['data' => $this->enJson([$collection])[0]]);
    }

    /** DELETE collections/{collection} : les publications restent, seule la collection part. */
    public function supprimer(Request $requete, Collection $collection): Response
    {
        $this->mienne($requete, $collection);
        $contenus = DB::table('enregistrements')->where('collection_id', $collection->id)->pluck('contenu_id');
        $collection->delete();
        $contenus->each(fn ($id) => Compteurs::contenu($id));

        return response()->noContent();
    }

    /** GET collections/{collection}/contenus : les derniers enregistrés d'abord. */
    public function contenus(Request $requete, Collection $collection): AnonymousResourceCollection
    {
        $this->voir($requete, $collection);
        $page = $collection->contenus()->publies()
            ->with(['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes'])
            ->avecMoi($requete->user('sanctum'))
            ->orderByDesc('enregistrements.id')
            ->cursorPaginate(30, cursorName: 'curseur');

        return ContenuResource::collection($page);
    }

    /** PUT collections/{collection}/contenus/{contenu} : enregistrer (deux fois ne change rien). */
    public function ajouter(Request $requete, Collection $collection, Contenu $contenu): JsonResponse
    {
        $this->mienne($requete, $collection);
        Gate::authorize('voir', $contenu);
        abort_unless($contenu->estVisible(), 404);
        $collection->contenus()->syncWithoutDetaching([$contenu->id]);
        $collection->touch();
        Compteurs::collection($collection->id);
        Compteurs::contenu($contenu->id);

        return response()->json(['enregistre' => true, 'collection' => $this->enJson([$collection->refresh()])[0]]);
    }

    /** DELETE collections/{collection}/contenus/{contenu} */
    public function retirer(Request $requete, Collection $collection, Contenu $contenu): JsonResponse
    {
        $this->mienne($requete, $collection);
        $collection->contenus()->detach($contenu->id);
        Compteurs::collection($collection->id);
        Compteurs::contenu($contenu->id);

        return response()->json(['enregistre' => false, 'collection' => $this->enJson([$collection->refresh()])[0]]);
    }
}
