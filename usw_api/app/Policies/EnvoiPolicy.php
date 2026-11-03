<?php

namespace App\Policies;

use App\Models\Envoi;
use App\Models\Utilisateur;
use Illuminate\Auth\Access\Response;

class EnvoiPolicy
{
    /** On n'envoie que dans ses propres envois ; ceux des autres n'existent pas. */
    public function envoyer(Utilisateur $u, Envoi $envoi): Response
    {
        return $u->id === $envoi->utilisateur_id ? Response::allow() : Response::denyAsNotFound();
    }
}
