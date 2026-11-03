<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['pays_id', 'nom', 'region'])]
class Ville extends Model
{
    use HasFactory;

    protected $table = 'villes';

    /** @return BelongsTo<Pays, $this> */
    public function pays(): BelongsTo
    {
        return $this->belongsTo(Pays::class);
    }

    /** @return HasMany<Lieu, $this> */
    public function lieux(): HasMany
    {
        return $this->hasMany(Lieu::class);
    }
}
