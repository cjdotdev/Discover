<?php

namespace App\Exceptions;

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Throwable;

/**
 * Une seule forme d'erreur pour toute l'API, que l'application affiche telle quelle
 * (ARCHITECTURE.md, section 5) :
 *
 *   { "message": "Code incorrect.", "erreurs": { "code": ["Code incorrect. Encore 4 essais."] } }
 *
 * « erreurs » n'apparaît que pour une validation (422).
 */
class ErreursApi
{
    /** Le message de chaque code, quand l'exception n'en donne pas. */
    private const MESSAGES = [
        400 => 'Requête incorrecte.',
        401 => 'Connectez-vous pour continuer.',
        403 => "Vous n'avez pas le droit de faire cela.",
        404 => 'Introuvable.',
        405 => 'Méthode non autorisée.',
        409 => 'Conflit avec l’état actuel.',
        413 => 'Le fichier est trop gros.',
        419 => 'La session a expiré.',
        422 => 'Les informations envoyées ne sont pas valides.',
        429 => 'Trop de demandes. Réessayez dans un instant.',
        500 => 'Une erreur est survenue. Réessayez plus tard.',
        503 => 'Discover est en maintenance. Réessayez dans quelques minutes.',
    ];

    public static function configurer(Exceptions $exceptions): void
    {
        $exceptions->shouldRenderJsonWhen(fn (Request $requete) => self::estApi($requete) || $requete->expectsJson());

        $exceptions->render(function (ValidationException $e, Request $requete) {
            if (self::estApi($requete)) {
                return self::reponse(422, $e->validator->errors()->first(), $e->errors());
            }
        });

        $exceptions->render(function (AuthenticationException $e, Request $requete) {
            if (self::estApi($requete)) {
                return self::reponse(401);
            }
        });

        $exceptions->render(function (AuthorizationException|AccessDeniedHttpException $e, Request $requete) {
            if (self::estApi($requete)) {
                // Une Policy peut cacher une ressource plutôt que la refuser (denyAsNotFound).
                return self::reponse($e instanceof AuthorizationException && $e->status() === 404 ? 404 : 403);
            }
        });

        // Un modèle introuvable arrive ici déjà converti : son nom de classe ne sort jamais.
        $exceptions->render(function (NotFoundHttpException $e, Request $requete) {
            if (self::estApi($requete)) {
                return self::reponse(404);
            }
        });

        $exceptions->render(function (ErreurMetier $e, Request $requete) {
            if (self::estApi($requete)) {
                return self::reponse($e->getStatusCode(), $e->getMessage());
            }
        });

        $exceptions->render(function (HttpExceptionInterface $e, Request $requete) {
            if (self::estApi($requete)) {
                $code = $e->getStatusCode();
                // Les messages anglais de Symfony et de Laravel restent dans les journaux.
                $message = self::MESSAGES[$code] ?? ($code >= 500 ? self::MESSAGES[500] : self::MESSAGES[400]);

                return self::reponse($code, $message)->withHeaders($e->getHeaders());
            }
        });

        // Une réponse déjà prête (une limite de débit atteinte : 429 et son délai) passe telle quelle.
        $exceptions->render(fn (HttpResponseException $e) => $e->getResponse());

        // Le reste : le détail seulement sur le poste de développement (Partie 27.3).
        $exceptions->render(function (Throwable $e, Request $requete) {
            if (self::estApi($requete) && ! config('app.debug')) {
                return self::reponse(500);
            }
        });
    }

    public static function estApi(Request $requete): bool
    {
        return $requete->is('api/*');
    }

    /**
     * @param  array<string, list<string>>|null  $erreurs
     */
    private static function reponse(int $code, ?string $message = null, ?array $erreurs = null): JsonResponse
    {
        // Dans la langue de l'application (middleware ChoisirLangue) : le texte français est la clé.
        $corps = ['message' => __($message ?? self::MESSAGES[$code])];
        if ($erreurs !== null) {
            $corps['erreurs'] = array_map(fn ($liste) => array_map(fn ($m) => is_string($m) ? __($m) : $m, (array) $liste), $erreurs);
        }

        return response()->json($corps, $code);
    }
}
