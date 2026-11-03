<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * La petite base SQLite du serveur (la file des tâches, le cache) : créée si elle manque.
 * Sur Railway, un disque neuf la perd alors que Neon garde la trace de sa migration ;
 * le démarrage (docker/demarrer.sh) la refait donc à chaque fois, sans rien écraser.
 */
#[Signature('usw:base-locale')]
#[Description('Crée la file des tâches et le cache dans la base SQLite du serveur, s’ils manquent')]
class PreparerBaseLocale extends Command
{
    public function handle(): int
    {
        $fichier = config('database.connections.locale.database');
        if ($fichier !== ':memory:' && ! file_exists($fichier)) {
            touch($fichier);
        }
        (require database_path('migrations/2026_10_24_150100_create_base_locale_tables.php'))->up();
        $this->info('Base locale prête.');

        return self::SUCCESS;
    }
}
