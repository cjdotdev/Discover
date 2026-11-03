<?php

use App\Models\Signalement;
use Illuminate\Foundation\Inspiring;
use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;
use Laravel\Sanctum\PersonalAccessToken;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Les comptes supprimés depuis plus de 30 jours (E21).
Schedule::command('usw:purger-comptes')->dailyAt('03:00');

// La recommandation : les scores des publications et des lieux (l'âge les fait baisser).
Schedule::command('usw:scores')->everyTenMinutes()->withoutOverlapping();

// L'IA décrit ce qu'on voit sur les publications (la recherche par le contenu).
Schedule::command('usw:decrire')->everyMinute()->withoutOverlapping(10);

// L'aperçu léger des reels publiés avant lui (les grilles le lisent), deux à chaque passage.
Schedule::command('usw:apercus-video')->everyMinute()->withoutOverlapping(10);

// Les envois abandonnés depuis 7 jours (B35).
Schedule::command('usw:purger-envois')->dailyAt('03:30');

// Ce qui ne sert plus, pour que la base reste petite : les codes de plus d'un jour (model:prune),
// les connexions de téléphones restés muets 6 mois.
Schedule::command('model:prune')->dailyAt('04:00');
Schedule::call(fn () => PersonalAccessToken::where('last_used_at', '<', now()->subMonths(6))
    ->orWhere(fn ($q) => $q->whereNull('last_used_at')->where('created_at', '<', now()->subMonths(6)))
    ->delete())->dailyAt('04:10')->name('jetons-muets');

// Les vues de plus de 30 jours et les « pas intéressé » de plus de 90 (la recommandation ne
// regarde pas plus loin), les travaux échoués de plus de 7 jours.
Schedule::call(function () {
    DB::table('vues')->where('jour', '<', today()->subDays(30))->delete();
    DB::table('desinterets')->where('created_at', '<', now()->subDays(90))->delete();
})->dailyAt('04:30')->name('vues-anciennes');
Schedule::command('queue:prune-failed', ['--hours' => 168])->dailyAt('04:40');

// Les signalements de plus d'un an (la politique de confidentialité le dit).
Schedule::call(fn () => Signalement::where('created_at', '<', now()->subYear())->delete())->dailyAt('04:50')->name('signalements-anciens');

// Le cache sur le disque du serveur : ce qui a expiré s'efface (il ne grossit pas sans fin).
Schedule::call(fn () => DB::connection(config('cache.stores.database.connection'))->table(config('cache.stores.database.table'))
    ->where('expiration', '<', time())->delete())->everyTenMinutes()->name('cache-expire');

// Les notifications de plus de 60 jours.
Schedule::call(fn () => DatabaseNotification::where('created_at', '<', now()->subDays(60))->delete())
    ->dailyAt('04:20')->name('notifications-anciennes');
