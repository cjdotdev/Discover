<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * « Gérer Discover » : l'équipe seule (ADMIN_EMAILS). Pour tout autre compte, ces adresses
 * n'existent pas (404, pas 403) : on ne révèle pas qu'il y a quelque chose ici.
 */
class EquipeSeule
{
    public function handle(Request $requete, Closure $suite): Response
    {
        abort_unless($requete->user()?->estAdmin(), 404);

        return $suite($requete);
    }
}
