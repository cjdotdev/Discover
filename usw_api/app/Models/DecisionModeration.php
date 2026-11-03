<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/** Une décision de modération (E25) : publier, refuser, masquer un commentaire, classer un signalement. */
#[Fillable(['contenu_id', 'commentaire_id', 'moderateur_id', 'decision', 'motif'])]
class DecisionModeration extends Model
{
    protected $table = 'decisions_moderation';
}
