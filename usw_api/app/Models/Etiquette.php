<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/** Ce que le téléphone voit sur une photo (une étiquette de Google ML Kit), et sa confiance. */
#[Fillable(['contenu_id', 'nom', 'confiance'])]
class Etiquette extends Model
{
    protected $table = 'etiquettes';

    public $timestamps = false;

    protected function casts(): array
    {
        return ['confiance' => 'float'];
    }
}
