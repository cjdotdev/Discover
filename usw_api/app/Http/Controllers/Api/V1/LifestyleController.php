<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\AuteurResource;
use App\Http\Resources\ContenuResource;
use App\Models\Contenu;
use App\Models\Utilisateur;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Str;

/**
 * Le lifestyle : l'album de vie de chaque membre. Ses publications ne passent pas à l'accueil ;
 * elles se voient ici, et seulement si le membre a rendu son lifestyle visible.
 */
class LifestyleController extends Controller
{
    /**
     * GET lifestyles?q= : les membres dont le lifestyle est visible, chacun avec sa pile (ses 4
     * dernières publications), ceux qui ont publié le plus récemment d'abord. 20 par page.
     */
    public function index(Request $requete): JsonResponse
    {
        $requete->validate(['q' => ['nullable', 'string', 'max:60'], 'curseur' => ['nullable', 'string', 'max:500']]);
        $moi = $requete->user('sanctum');
        $q = Str::lower(Str::ascii(ltrim(trim((string) $requete->query('q')), '@')));
        $page = Utilisateur::query()
            ->where('lifestyle_visible', true)->whereNull('suspendu_le')->whereNull('suppression_demandee_le')
            ->whereHas('lifestyle')
            ->when($q !== '', fn ($w) => $w->where(fn ($n) => $n->where('nom_utilisateur', 'like', "%{$q}%")->orWhereRaw('lower(nom_affiche) like ?', ["%{$q}%"])))
            // Ni ceux qui m'ont bloqué, ni ceux que j'ai bloqués.
            ->when($moi !== null, fn ($w) => $w->whereNotIn('id', fn ($b) => $b->select('bloqueur_id')->from('blocages')->where('bloque_id', $moi->id))
                ->whereNotIn('id', fn ($b) => $b->select('bloque_id')->from('blocages')->where('bloqueur_id', $moi->id)))
            ->withMax('lifestyle as dernier_le', 'publie_le')
            ->withCount('lifestyle as nombre_lifestyle')
            ->with(['lifestyle' => fn ($l) => $l->limit(4)->with('variantes')])
            ->orderByDesc('dernier_le')->orderByDesc('id')
            ->cursorPaginate(20, cursorName: 'curseur');

        return response()->json([
            'data' => $page->getCollection()->map(fn (Utilisateur $u) => [
                'auteur' => (new AuteurResource($u))->resolve($requete),
                'nombre' => (int) $u->nombre_lifestyle,
                'photos' => ContenuResource::collection($u->lifestyle->each->setRelation('auteur', $u))->resolve($requete),
            ])->values()->all(),
            'meta' => ['next_cursor' => $page->nextCursor()?->encode()],
        ]);
    }

    /** GET utilisateurs/{nom}/lifestyle : son lifestyle, s'il est visible (ou si c'est le mien). */
    public function deMembre(Request $requete, string $nom): AnonymousResourceCollection
    {
        $u = Utilisateur::where('nom_utilisateur', Str::lower($nom))->whereNull('suspendu_le')->firstOrFail();
        $moi = $requete->user('sanctum');
        $cEstMoi = $moi !== null && $moi->id === $u->id;
        abort_unless($cEstMoi || $u->lifestyle_visible, 404);
        abort_if($moi !== null && $u->aBloque($moi), 404);

        return $this->page($requete, $u);
    }

    /** GET moi/lifestyle : le mien, avec son réglage (visible ou non). */
    public function moi(Request $requete): JsonResponse
    {
        $u = $requete->user();

        return $this->page($requete, $u)->additional(['visible' => (bool) $u->lifestyle_visible])->response();
    }

    /** PUT moi/lifestyle {visible} : rendre mon lifestyle visible des autres, ou le garder pour moi. */
    public function regler(Request $requete): JsonResponse
    {
        $d = $requete->validate(['visible' => ['required', 'boolean']]);
        $requete->user()->forceFill(['lifestyle_visible' => $d['visible']])->save();

        return response()->json(['visible' => (bool) $d['visible']]);
    }

    private function page(Request $requete, Utilisateur $u): AnonymousResourceCollection
    {
        $page = Contenu::duLifestyle()->where('utilisateur_id', $u->id)->avecMoi($requete->user('sanctum'))
            ->with(['lieu.ville.pays', 'capture.modele', 'variantes'])
            ->orderByDesc('publie_le')->orderByDesc('id')
            ->cursorPaginate(20, cursorName: 'curseur');
        $page->getCollection()->each->setRelation('auteur', $u);

        return ContenuResource::collection($page);
    }
}
