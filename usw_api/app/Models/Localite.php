<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/** Une ville ou un village du monde (GeoNames), pour le choix de la ville du profil. */
#[Fillable(['geoname_id', 'pays', 'nom', 'recherche', 'region', 'population', 'latitude', 'longitude'])]
class Localite extends Model
{
    public $timestamps = false;

    protected function casts(): array
    {
        return ['latitude' => 'float', 'longitude' => 'float', 'population' => 'integer'];
    }

    /** « Abomey-Calavi » → « abomey calavi ». */
    public static function normaliser(string $texte): string
    {
        return trim((string) preg_replace('/[^a-z0-9]+/', ' ', Str::lower(Str::ascii($texte))));
    }
}
