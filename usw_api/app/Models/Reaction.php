<?php

namespace App\Models;

use App\Services\Contenus\Compteurs;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Une réaction (E06) : une par membre et par contenu. */
#[Fillable(['utilisateur_id', 'contenu_id', 'type'])]
class Reaction extends Model
{
    /** Les quatre réactions de Discover, et ce que l'application affiche. */
    public const TYPES = ['coeur' => '❤️', 'waouh' => '🤩', 'voyage' => '🧳', 'merci' => '🙏'];

    protected static function booted(): void
    {
        static::saved(fn (Reaction $r) => Compteurs::contenu($r->contenu_id));
        static::deleted(fn (Reaction $r) => Compteurs::contenu($r->contenu_id));
    }

    /** @return BelongsTo<Utilisateur, $this> */
    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class);
    }

    /** @return BelongsTo<Contenu, $this> */
    public function contenu(): BelongsTo
    {
        return $this->belongsTo(Contenu::class);
    }
}
