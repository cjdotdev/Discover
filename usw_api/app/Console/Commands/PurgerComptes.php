<?php

namespace App\Console\Commands;

use App\Models\Utilisateur;
use App\Services\Compte\Comptes;
use App\Support\Medias;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Chaque nuit (routes/console.php) : efface les comptes dont la suppression a été
 * demandée il y a plus de 30 jours, avec leur photo de profil et leurs jetons.
 */
#[Signature('usw:purger-comptes')]
#[Description('Efface les comptes supprimés depuis plus de 30 jours')]
class PurgerComptes extends Command
{
    public function handle(): int
    {
        $limite = now()->subDays(Utilisateur::JOURS_AVANT_SUPPRESSION);
        $nombre = 0;
        Utilisateur::where('suppression_demandee_le', '<=', $limite)->chunkById(100, function ($comptes) use (&$nombre) {
            foreach ($comptes as $u) {
                Comptes::effacerAvatar($u->avatar);
                // Ses photos et ses reels partent avec lui, fichiers compris.
                $u->contenus()->with('envois')->each(fn ($c) => Medias::effacer($c));
                $u->tokens()->delete();
                $u->delete();
                $nombre++;
            }
        });
        $this->info("{$nombre} compte(s) effacé(s).");

        return self::SUCCESS;
    }
}
