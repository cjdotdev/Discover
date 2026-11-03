<?php

namespace App\Http\Middleware;

use App\Models\Utilisateur;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

/**
 * Qui est là : la dernière activité d'un membre connecté (en ligne : moins de 5 minutes), et
 * les jours où il a ouvert Discover (les actifs du jour, de la semaine, du mois). Deux écritures
 * au plus toutes les 2 minutes par membre, pas à chaque requête.
 */
class NoterActivite
{
    public function handle(Request $requete, Closure $suite): Response
    {
        $reponse = $suite($requete);
        $u = $requete->user('sanctum');
        if ($u instanceof Utilisateur && ($u->derniere_activite_le === null || $u->derniere_activite_le->lt(now()->subMinutes(2)))) {
            Utilisateur::whereKey($u->id)->update(['derniere_activite_le' => now()]);
            DB::table('activites_jour')->insertOrIgnore(['utilisateur_id' => $u->id, 'jour' => now()->toDateString()]);
        }

        return $reponse;
    }
}
