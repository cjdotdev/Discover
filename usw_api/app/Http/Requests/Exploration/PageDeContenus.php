<?php

namespace App\Http\Requests\Exploration;

use Illuminate\Validation\Rule;

/** GET utilisateurs/{nom}/contenus et moi/contenus : ?type=reel&curseur=… */
class PageDeContenus extends Exploration
{
    public function rules(): array
    {
        return ['type' => ['nullable', Rule::in(['photo', 'reel'])], 'curseur' => self::curseur()];
    }
}
