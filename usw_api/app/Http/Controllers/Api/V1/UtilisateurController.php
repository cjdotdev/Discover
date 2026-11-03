<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Exploration\PageDeContenus;
use App\Http\Resources\ContenuResource;
use App\Http\Resources\CreateurResource;
use App\Models\Utilisateur;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Les créateurs (E20), par leur nom d'utilisateur, ouverts aux visiteurs. */
class UtilisateurController extends Controller
{
    private function trouver(string $nom): Utilisateur
    {
        return Utilisateur::where('nom_utilisateur', mb_strtolower(ltrim($nom, '@')))
            ->whereNull('suppression_demandee_le')
            ->whereNull('suspendu_le')
            ->withCount(['contenus as nombre_publies' => fn ($c) => $c->publies(), 'lifestyle as nombre_lifestyle'])
            ->firstOrFail();
    }

    /** GET utilisateurs/{nom} */
    public function afficher(string $nom): CreateurResource
    {
        $u = $this->trouver($nom);
        // Il nous a bloqués : son profil n'existe pas pour nous.
        $moi = request()->user('sanctum');
        abort_if($moi !== null && $u->aBloque($moi), 404);

        return new CreateurResource($u);
    }

    /** GET utilisateurs/{nom}/contenus : ses photos et reels publiés, les plus récents d'abord. */
    public function contenus(PageDeContenus $requete, string $nom): AnonymousResourceCollection
    {
        $u = $this->trouver($nom);
        $page = $u->contenus()->publies()->avecMoi($requete->user('sanctum'))
            ->when($requete->validated('type'), fn ($q, $type) => $q->where('type', $type))
            ->with(['lieu.ville.pays', 'capture.modele', 'variantes'])
            ->orderByDesc('publie_le')->orderByDesc('id')
            ->cursorPaginate(20, cursorName: 'curseur');
        // L'auteur est le même pour toute la page : pas besoin de le recharger à chaque contenu.
        $page->getCollection()->each->setRelation('auteur', $u);

        return ContenuResource::collection($page);
    }
}
