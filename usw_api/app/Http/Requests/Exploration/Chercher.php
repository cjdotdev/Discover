<?php

namespace App\Http\Requests\Exploration;

/** GET recherche?q=grand popo */
class Chercher extends Exploration
{
    public function rules(): array
    {
        return ['q' => ['required', 'string', 'min:1', 'max:60']];
    }
}
