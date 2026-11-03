<?php

namespace App\Support;

use Illuminate\Http\Request;

/**
 * Qui regarde : un membre connecté (« u:<id> »), sinon l'adresse IP (son préfixe /64 en IPv6, ce
 * qu'un abonné reçoit d'un bloc), gardée seulement sous forme d'empreinte. Un en-tête choisi par
 * le téléphone ne compte pas : n'importe qui pourrait en changer à chaque requête.
 */
class Spectateur
{
    public static function de(Request $requete): string
    {
        $moi = $requete->user('sanctum');
        if ($moi !== null) {
            return 'u:'.$moi->id;
        }

        return 'a:'.substr(hash('sha256', 'ip:'.self::ip($requete).'|'.config('app.key')), 0, 40);
    }

    /** L'IP pour les limites et les comptes : une IPv6 compte pour son /64. */
    public static function ip(Request $requete): string
    {
        $ip = (string) $requete->ip();
        if (str_contains($ip, ':') && ($binaire = @inet_pton($ip)) !== false) {
            return inet_ntop(substr($binaire, 0, 8).str_repeat("\0", 8)).'/64';
        }

        return $ip;
    }
}
