<?php

namespace App\Providers;

use App\Models\Utilisateur;
use App\Services\Compte\VerificateurGoogle;
use App\Services\Compte\VerificateurJetonGoogle;
use App\Support\ChargeurLangues;
use App\Support\Spectateur;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\PersonalAccessToken;
use Laravel\Sanctum\Sanctum;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Les traductions lisent aussi les paquets de langue de l'application (resources/langues).
        $this->app->extend('translation.loader', fn ($chargeur, $app) => new ChargeurLangues(
            $app['files'],
            [$app->basePath('vendor/laravel/framework/src/Illuminate/Translation/lang'), $app->langPath()],
        ));

        // Les tests remplacent la vérification par Google par un double (ARCHITECTURE.md, section 4).
        $this->app->bind(VerificateurJetonGoogle::class, fn () => new VerificateurGoogle(
            array_values(array_filter(array_map('trim', explode(',', (string) config('services.google.client_ids')))))
        ));
    }

    public function boot(): void
    {
        $this->limites();

        // La petite base du serveur (file des tâches, cache) se crée d'elle-même sur un serveur neuf.
        $locale = (string) config('database.connections.locale.database');
        if ($locale !== ':memory:' && $locale !== '' && ! is_file($locale) && is_dir(dirname($locale))) {
            touch($locale);
        }

        // Une relation oubliée dans un with() se voit tout de suite, hors production (N+1, section 6.4).
        Model::preventLazyLoading(! $this->app->isProduction());

        // La modération : l'équipe seule (ADMIN_EMAILS).
        Gate::define('moderer', fn (Utilisateur $u) => $u->estAdmin());

        // Un jeton expire après 30 jours sans usage (ARCHITECTURE.md, section 6.1).
        Sanctum::authenticateAccessTokensUsing(function (PersonalAccessToken $jeton, bool $valable) {
            $dernier = $jeton->last_used_at ?? $jeton->created_at;

            // Un compte suspendu par l'équipe perd l'accès sur tous ses téléphones.
            return $valable && $dernier !== null && $dernier->gt(now()->subDays(30)) && $jeton->tokenable?->suspendu_le === null;
        });
    }

    /** Les limites de débit du compte (section 6.1 et 9.2). */
    private function limites(): void
    {
        // Trop de demandes : 429, avec le temps à attendre (en-tête Retry-After, et dans le message).
        $trop = function (Request $r, array $entetes) {
            $secondes = (int) ($entetes['Retry-After'] ?? 60);
            $attente = $secondes >= 120 ? intdiv($secondes + 59, 60).' minutes' : ($secondes > 60 ? 'une minute' : $secondes.' secondes');

            return response()->json(['message' => __('Trop de demandes. Réessayez dans :attente.', ['attente' => $attente])], 429, $entetes);
        };

        // Les codes par e-mail (envoyer un e-mail coûte, et inonder une boîte est une attaque).
        // Par adresse et par IP : 1 par minute, 5 par heure ; quelqu'un d'autre qui tape votre
        // adresse ne vous bloque donc pas. Par adresse, toutes IP : 30 par jour. Par IP : 60 par
        // heure, 300 par jour : derriere une meme IP, il y a souvent des centaines de personnes (les
        // operateurs mobiles partagent leurs IP, un Wi-Fi d ecole aussi). Pour tout Discover : 600
        // par heure, 3 000 par jour.
        RateLimiter::for('codes', function (Request $r) use ($trop) {
            $email = 'email:'.mb_strtolower(trim((string) $r->input('email')));
            $ip = Spectateur::ip($r);

            return [
                Limit::perMinute(1)->by($email.'|'.$ip)->response($trop),
                Limit::perHour(5)->by('h:'.$email.'|'.$ip)->response($trop),
                Limit::perDay(30)->by('j:'.$email)->response($trop),
                Limit::perHour(60)->by('ip:'.$ip)->response($trop),
                Limit::perDay(300)->by('ipj:'.$ip)->response($trop),
                Limit::perHour(600)->by('codes:tous')->response($trop),
                Limit::perDay(3000)->by('codes:tous:jour')->response($trop),
            ];
        });

        // Les essais de code : 60 par minute par IP (une IP partagee), 20 par heure par adresse et par IP, 100 par
        // heure par adresse. Un code ne s'essaie qu'avec son défi : deviner celui d'un autre
        // demanderait aussi son secret.
        RateLimiter::for('connexion', function (Request $r) use ($trop) {
            $email = mb_strtolower(trim((string) $r->input('email')));
            $ip = Spectateur::ip($r);

            return array_filter([
                Limit::perMinute(60)->by('ip:'.$ip)->response($trop),
                $email === '' ? null : Limit::perHour(20)->by('essais:'.$email.'|'.$ip)->response($trop),
                $email === '' ? null : Limit::perHour(100)->by('essais:'.$email)->response($trop),
            ]);
        });

        // Google Places est payant à chaque recherche : 30 par minute et 500 par jour par membre,
        // 5 000 par jour pour tout Discover.
        RateLimiter::for('places', fn (Request $r) => [
            Limit::perMinute(30)->by('u:'.$r->user()?->id)->response($trop),
            Limit::perDay(500)->by('j:'.$r->user()?->id)->response($trop),
            Limit::perDay(5000)->by('places:tous')->response($trop),
        ]);

        // Toute l'API, en dernier rempart contre l'inondation : 300 requêtes par minute et par IP
        // (ou par membre). Bien au-dessus d'un usage normal, même en faisant défiler très vite.
        RateLimiter::for('api', fn (Request $r) => Limit::perMinute(300)->by($r->user('sanctum') ? 'u:'.$r->user('sanctum')->id : 'ip:'.Spectateur::ip($r))->response($trop));

        // Explorer : 120 pages par minute, par membre ou, pour un visiteur, par adresse IP.
        RateLimiter::for('explorer', fn (Request $r) => Limit::perMinute(120)->by($r->user('sanctum') ? 'u:'.$r->user('sanctum')->id : 'ip:'.Spectateur::ip($r))->response($trop));

        // Agir (réagir, suivre, enregistrer) : 120 par minute ; commenter : 10 par minute et 200 par jour.
        RateLimiter::for('agir', fn (Request $r) => Limit::perMinute(120)->by('u:'.$r->user()?->id)->response($trop));
        RateLimiter::for('commenter', fn (Request $r) => [
            Limit::perMinute(10)->by('u:'.$r->user()?->id)->response($trop),
            Limit::perDay(200)->by('j:'.$r->user()?->id)->response($trop),
        ]);

        // Publier : 30 contenus par heure et par membre ; les morceaux, 240 par minute.
        RateLimiter::for('publier', fn (Request $r) => Limit::perHour(30)->by('u:'.$r->user()?->id)->response($trop));
        RateLimiter::for('morceaux', fn (Request $r) => Limit::perMinute(240)->by('u:'.$r->user()?->id)->response($trop));
    }
}
