<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/** Un membre ne veut plus voir un autre membre (ni être vu de lui dans ses commentaires). */
#[Fillable(['bloqueur_id', 'bloque_id'])]
class Blocage extends Model {}
