<?php

namespace App\Models;

use App\Services\Contenus\Compteurs;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Un commentaire, ou la réponse à un commentaire (un seul niveau de fil). */
#[Fillable(['contenu_id', 'utilisateur_id', 'parent_id', 'repond_a_id', 'texte', 'epingle', 'masque', 'mentions'])]
class Commentaire extends Model
{
    use HasUlids;

    protected $table = 'commentaires';

    public function uniqueIds(): array
    {
        return ['ulid'];
    }

    public function getRouteKeyName(): string
    {
        return 'ulid';
    }

    protected function casts(): array
    {
        return ['epingle' => 'boolean', 'masque' => 'boolean', 'mentions' => 'array', 'nombre_jaime' => 'integer', 'nombre_reponses' => 'integer'];
    }

    protected static function booted(): void
    {
        $suivre = function (Commentaire $c) {
            Compteurs::contenu($c->contenu_id);
            Compteurs::commentaire($c->parent_id);
        };
        static::created($suivre);
        static::deleted($suivre);
        static::updated(fn (Commentaire $c) => $c->wasChanged('masque') ? $suivre($c) : null);
    }

    /** Ceux qui se voient : pas les commentaires masqués par la modération. */
    public function scopeVisibles(Builder $q): void
    {
        $q->where('masque', false);
    }

    /** @return BelongsTo<Utilisateur, $this> */
    public function auteur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }

    /** @return BelongsTo<Utilisateur, $this> */
    public function repondA(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'repond_a_id');
    }

    /** @return BelongsTo<Contenu, $this> */
    public function contenu(): BelongsTo
    {
        return $this->belongsTo(Contenu::class);
    }

    /** @return BelongsTo<Commentaire, $this> */
    public function parent(): BelongsTo
    {
        return $this->belongsTo(Commentaire::class, 'parent_id');
    }

    /** @return HasMany<Commentaire, $this> */
    public function reponses(): HasMany
    {
        return $this->hasMany(Commentaire::class, 'parent_id');
    }

    /** @return HasMany<JaimeCommentaire, $this> */
    public function jaimes(): HasMany
    {
        return $this->hasMany(JaimeCommentaire::class);
    }
}
