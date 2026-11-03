<?php

namespace App\Models;

use App\Enums\UsageVariante;
use App\Support\Medias;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Une taille servie au public : 480, 1080, 2160 px, le flou d'attente, la vidéo, l'affiche. */
#[Fillable(['contenu_id', 'usage', 'chemin', 'largeur', 'hauteur'])]
class Variante extends Model
{
    use HasFactory;

    protected $table = 'variantes';

    protected function casts(): array
    {
        return ['usage' => UsageVariante::class];
    }

    /** @return BelongsTo<Contenu, $this> */
    public function contenu(): BelongsTo
    {
        return $this->belongsTo(Contenu::class);
    }

    public function url(): string
    {
        return Medias::public()->url($this->chemin);
    }
}
