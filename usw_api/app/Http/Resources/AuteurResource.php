<?php

namespace App\Http\Resources;

use App\Models\Utilisateur;
use App\Support\Medias;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Un membre tel que les autres le voient : jamais son e-mail.
 *
 * @mixin Utilisateur
 */
class AuteurResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->ulid,
            'nom_utilisateur' => $this->nom_utilisateur,
            'nom_affiche' => $this->nom_affiche,
            'avatar' => $this->avatar ? Medias::public()->url($this->avatar) : null,
        ];
    }
}
