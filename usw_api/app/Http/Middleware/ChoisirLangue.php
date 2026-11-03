<?php

namespace App\Http\Middleware;

use App\Support\Langues;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;
use Symfony\Component\HttpFoundation\Response;

/**
 * La langue de la réponse : celle que l'application envoie (Accept-Language), si le serveur la
 * connaît ; sinon le français. Un membre connecté la garde : ses notifications la suivent.
 */
class ChoisirLangue
{
    public function handle(Request $requete, Closure $suite): Response
    {
        $langue = Langues::choisir($requete->header('Accept-Language')) ?? Langues::SOURCE;
        App::setLocale($langue);
        // Un texte sans traduction reste en français (jamais une clé brute).
        app('translator')->setFallback(Langues::SOURCE);

        $reponse = $suite($requete);

        $moi = $requete->user('sanctum');
        if ($moi !== null && $requete->hasHeader('Accept-Language') && $moi->langue !== $langue) {
            $moi->newQuery()->whereKey($moi->getKey())->update(['langue' => $langue]);
        }

        return $reponse;
    }
}
