<?php

use App\Exceptions\ErreursApi;
use App\Http\Middleware\ChoisirLangue;
use App\Http\Middleware\EnTetesSecurite;
use App\Http\Middleware\EquipeSeule;
use App\Http\Middleware\NoterActivite;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        // Toutes les routes de l'application mobile : /api/v1/… (ARCHITECTURE.md, section 8).
        api: __DIR__.'/../routes/api.php',
        apiPrefix: 'api/v1',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Derrière le proxy de Railway (HTTPS) : les adresses générées restent en https.
        $middleware->trustProxies(at: '*');
        $middleware->api(append: [NoterActivite::class]);
        // Toute l'API : une limite de débit générale (AppServiceProvider, « api »), en dernier rempart.
        $middleware->throttleApi('api');
        // Les en-têtes de sécurité, sur l'API comme sur les pages des liens partagés.
        $middleware->append(EnTetesSecurite::class);
        $middleware->appendToGroup('api', ChoisirLangue::class);
        $middleware->alias(['equipe' => EquipeSeule::class]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        ErreursApi::configurer($exceptions);
    })->create();
