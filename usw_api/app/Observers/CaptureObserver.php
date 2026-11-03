<?php

namespace App\Observers;

use App\Models\Capture;
use App\Services\Contenus\Compteurs;

class CaptureObserver
{
    public function saved(Capture $capture): void
    {
        Compteurs::modele($capture->modele_telephone_id);
        if ($capture->wasChanged('modele_telephone_id')) {
            Compteurs::modele($capture->getOriginal('modele_telephone_id'));
        }
    }
}
