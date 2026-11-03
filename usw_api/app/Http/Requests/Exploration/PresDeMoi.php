<?php

namespace App\Http\Requests\Exploration;

/** GET flux/pres-de-moi?latitude=…&longitude=…&rayon=50&types=… */
class PresDeMoi extends Exploration
{
    public function rules(): array
    {
        return [...self::position(true), 'types' => self::typesListe()];
    }
}
