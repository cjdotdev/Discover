<?php

namespace App\Observers;

use App\Http\Controllers\Api\V1\ExplorationController;
use App\Models\Contenu;
use App\Services\Contenus\Compteurs;

/** Un contenu publié, retiré, déplacé ou effacé : les compteurs de son lieu, de son téléphone et de sa musique suivent. */
class ContenuObserver
{
    public function saved(Contenu $contenu): void
    {
        if (! $contenu->wasChanged(['statut', 'lieu_id']) && ! $contenu->wasRecentlyCreated) {
            return;
        }
        Compteurs::lieu($contenu->lieu_id);
        if ($contenu->wasChanged('lieu_id')) {
            Compteurs::lieu($contenu->getOriginal('lieu_id'));
        }
        Compteurs::modele($contenu->capture()->value('modele_telephone_id'));
        Compteurs::son($contenu->son_id);
        // L'accueil gardé en cache se refait avec ce contenu (ou sans lui).
        ExplorationController::fluxChange();
    }

    public function deleted(Contenu $contenu): void
    {
        Compteurs::lieu($contenu->lieu_id);
        Compteurs::son($contenu->son_id);
        ExplorationController::fluxChange();
    }
}
