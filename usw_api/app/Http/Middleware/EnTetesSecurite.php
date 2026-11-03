<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Les en-têtes de sécurité de chaque réponse : pas de devinette du type des fichiers, pas
 * d'intégration de nos pages dans un autre site, HTTPS seulement, aucune adresse d'origine
 * envoyée ailleurs en entier, ni caméra, ni micro, ni position pour une page web.
 */
class EnTetesSecurite
{
    public function handle(Request $requete, Closure $suite): Response
    {
        $reponse = $suite($requete);
        $h = $reponse->headers;
        $h->set('X-Content-Type-Options', 'nosniff');
        $h->set('X-Frame-Options', 'DENY');
        $h->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $h->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
        if ($requete->isSecure()) {
            $h->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        }

        return $reponse;
    }
}
