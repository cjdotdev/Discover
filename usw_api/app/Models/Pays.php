<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['code', 'nom'])]
class Pays extends Model
{
    use HasFactory;

    protected $table = 'pays';

    /** @return HasMany<Ville, $this> */
    public function villes(): HasMany
    {
        return $this->hasMany(Ville::class);
    }
}
