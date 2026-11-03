<?php

namespace App\Models;

use App\Enums\SourceCapture;
use App\Observers\CaptureObserver;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\ObservedBy;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Ce que l'on sait de la prise d'un contenu, et d'où vient chaque information. */
#[Fillable(['contenu_id', 'source', 'modele_telephone_id', 'prise_le', 'latitude', 'longitude', 'origines'])]
#[ObservedBy(CaptureObserver::class)]
class Capture extends Model
{
    use HasFactory;

    protected $table = 'captures';

    protected function casts(): array
    {
        return [
            'source' => SourceCapture::class,
            'prise_le' => 'datetime',
            'latitude' => 'float',
            'longitude' => 'float',
            'origines' => 'array',
        ];
    }

    /** @return BelongsTo<Contenu, $this> */
    public function contenu(): BelongsTo
    {
        return $this->belongsTo(Contenu::class);
    }

    /** @return BelongsTo<ModeleTelephone, $this> */
    public function modele(): BelongsTo
    {
        return $this->belongsTo(ModeleTelephone::class, 'modele_telephone_id');
    }
}
