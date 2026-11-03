<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Le fichier envoyé, tel quel. Son empreinte évite les doublons ; le fichier lui-même reste sur le
 * téléphone de son auteur une fois vérifié (`chemin` vide), sauf si le serveur garde les originaux.
 */
#[Fillable(['contenu_id', 'empreinte_sha256', 'format', 'largeur', 'hauteur', 'poids', 'chemin'])]
#[Hidden(['chemin'])]
class FichierOriginal extends Model
{
    protected $table = 'fichiers_originaux';

    /** @return BelongsTo<Contenu, $this> */
    public function contenu(): BelongsTo
    {
        return $this->belongsTo(Contenu::class);
    }
}
