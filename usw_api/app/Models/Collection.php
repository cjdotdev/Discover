<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

/** Une collection d'enregistrements (E19), secrète ou visible sur le profil. */
#[Fillable(['utilisateur_id', 'nom', 'secrete'])]
class Collection extends Model
{
    use HasUlids;

    protected $table = 'collections';

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
        return ['secrete' => 'boolean', 'nombre_contenus' => 'integer'];
    }

    /** @return BelongsTo<Utilisateur, $this> */
    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class);
    }

    /** @return BelongsToMany<Contenu, $this> */
    public function contenus(): BelongsToMany
    {
        return $this->belongsToMany(Contenu::class, 'enregistrements')->withTimestamps();
    }
}
