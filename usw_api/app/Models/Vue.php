<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Une vue : une personne a regardé une publication (au moins 2 s une photo, 3 s un reel), ce jour-là. */
#[Fillable(['contenu_id', 'spectateur', 'jour', 'duree_ms', 'complete'])]
class Vue extends Model
{
    protected $table = 'vues';

    protected function casts(): array
    {
        return ['jour' => 'date', 'complete' => 'boolean', 'duree_ms' => 'integer'];
    }

    /** @return BelongsTo<Contenu, $this> */
    public function contenu(): BelongsTo
    {
        return $this->belongsTo(Contenu::class);
    }
}
