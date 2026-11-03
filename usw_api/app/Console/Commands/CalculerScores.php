<?php

namespace App\Console\Commands;

use App\Http\Controllers\Api\V1\ExplorationController;
use App\Services\Contenus\Recommandation;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/** Toutes les 10 minutes : les scores de recommandation des publications et des lieux. */
#[Signature('usw:scores')]
#[Description('Recalcule les scores de recommandation (publications et lieux)')]
class CalculerScores extends Command
{
    public function handle(): int
    {
        $n = Recommandation::recalculer();
        // L'accueil gardé en cache suit le nouvel ordre.
        ExplorationController::fluxChange();
        $this->info("{$n} score(s) changé(s).");

        return self::SUCCESS;
    }
}
