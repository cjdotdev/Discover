<?php

namespace App\Models;

use App\Services\Contenus\Compteurs;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/** Un membre suit un créateur. */
#[Fillable(['abonne_id', 'createur_id'])]
class Abonnement extends Model
{
    protected static function booted(): void
    {
        $suivre = function (Abonnement $a) {
            Compteurs::membre($a->abonne_id);
            Compteurs::membre($a->createur_id);
        };
        static::created($suivre);
        static::deleted($suivre);
    }
}
