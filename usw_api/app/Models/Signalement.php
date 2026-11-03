<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;

/** Un signalement (E22). Son auteur n'est jamais montré à celui qu'il vise. */
#[Fillable(['utilisateur_id', 'cible_type', 'cible_id', 'motif', 'precision', 'statut'])]
#[Hidden(['utilisateur_id'])]
class Signalement extends Model {}
