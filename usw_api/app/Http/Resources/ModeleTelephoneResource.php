<?php

namespace App\Http\Resources;

use App\Models\ModeleTelephone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ModeleTelephone */
class ModeleTelephoneResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'marque' => $this->marque,
            'nom' => $this->nom,
            'complet' => $this->complet(),
            'nombre_contenus' => $this->nombre_contenus,
        ];
    }
}
