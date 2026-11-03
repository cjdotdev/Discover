<?php

namespace App\Policies;

use App\Models\Contenu;
use App\Models\Utilisateur;
use Illuminate\Auth\Access\Response;

class ContenuPolicy
{
    /**
     * Un contenu publié se voit par tous, même sans compte, sauf si son auteur est suspendu ; un
     * brouillon ou un contenu refusé, par son auteur seul. Pour les autres il n'existe pas : 404.
     */
    public function voir(?Utilisateur $u, Contenu $contenu): Response
    {
        return ($u !== null && $u->id === $contenu->utilisateur_id) || $contenu->estVisible()
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    /** Compléter ou supprimer : l'auteur seul ; pour les autres, il n'existe pas. */
    public function modifier(Utilisateur $u, Contenu $contenu): Response
    {
        return $u->id === $contenu->utilisateur_id ? Response::allow() : Response::denyAsNotFound();
    }
}
