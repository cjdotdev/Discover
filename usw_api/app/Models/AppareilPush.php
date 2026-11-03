<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Un téléphone qui reçoit les notifications, et ce que son membre a choisi d'y recevoir. */
class AppareilPush extends Model
{
    protected $table = 'appareils_push';

    protected $fillable = ['utilisateur_id', 'jeton', 'jeton_acces_id', 'preferences', 'pause_jusqu_a'];

    protected function casts(): array
    {
        return [
            'preferences' => 'array',
            'pause_jusqu_a' => 'datetime',
        ];
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class);
    }

    /**
     * Ce téléphone veut-il ce genre de notification ? `$preference` : la ligne des réglages
     * (jaime, commentaires…) ; null pour ce qui prévient toujours (publication retirée, équipe).
     */
    public function accepte(?string $preference): bool
    {
        if ($preference === null) {
            return true;
        }
        if ($this->pause_jusqu_a?->isFuture()) {
            return false;
        }

        return ($this->preferences[$preference] ?? true) !== false;
    }
}
