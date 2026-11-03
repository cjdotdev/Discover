<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\MassPrunable;
use Illuminate\Database\Eloquent\Model;

/** Un code à 6 chiffres envoyé par e-mail ; seul son haché est gardé, et un jour au plus. */
#[Fillable(['email', 'but', 'code_hache', 'defi_hache', 'essais', 'expire_le', 'utilise_le'])]
#[Hidden(['code_hache', 'defi_hache'])]
class CodeEmail extends Model
{
    use MassPrunable;

    protected $table = 'codes_email';

    protected function casts(): array
    {
        return [
            'expire_le' => 'datetime',
            'utilise_le' => 'datetime',
            'essais' => 'integer',
        ];
    }

    public function estValable(): bool
    {
        return $this->utilise_le === null && $this->expire_le->isFuture() && $this->essais < 5;
    }

    /** Chaque nuit (model:prune) : un code n'a plus rien à dire au bout d'un jour. */
    public function prunable(): Builder
    {
        return static::where('created_at', '<', now()->subDay());
    }
}
