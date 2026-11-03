<?php

namespace App\Http\Requests\Exploration;

/** GET carte?nord=…&sud=…&est=…&ouest=…&types=… : la partie de la carte à l'écran. */
class ZoneDeCarte extends Exploration
{
    public function rules(): array
    {
        return [
            'nord' => ['required', 'numeric', 'between:-90,90'],
            'sud' => ['required', 'numeric', 'between:-90,90', 'lte:nord'],
            'est' => ['required', 'numeric', 'between:-180,180'],
            'ouest' => ['required', 'numeric', 'between:-180,180'],
            'types' => self::typesListe(),
        ];
    }
}
