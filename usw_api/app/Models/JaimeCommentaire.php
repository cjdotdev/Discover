<?php

namespace App\Models;

use App\Services\Contenus\Compteurs;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/** « J'aime » sur un commentaire. */
#[Fillable(['utilisateur_id', 'commentaire_id'])]
class JaimeCommentaire extends Model
{
    protected $table = 'jaimes_commentaires';

    protected static function booted(): void
    {
        static::created(fn (JaimeCommentaire $j) => Compteurs::commentaire($j->commentaire_id));
        static::deleted(fn (JaimeCommentaire $j) => Compteurs::commentaire($j->commentaire_id));
    }
}
