<?php

namespace App\Http\Requests\Exploration;

/** GET flux/decouverte?curseur=…&types=Plages,Cascades */
class FluxDecouverte extends Exploration
{
    public function rules(): array
    {
        return ['curseur' => self::curseur(), 'types' => self::typesListe()];
    }
}
