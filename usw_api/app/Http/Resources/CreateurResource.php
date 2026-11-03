<?php

namespace App\Http\Resources;

use App\Models\Utilisateur;
use App\Support\Medias;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Le profil public d'un créateur (E20) : ce qu'il a choisi de montrer. Jamais son e-mail.
 *
 * @mixin Utilisateur
 */
class CreateurResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->ulid,
            'nom_utilisateur' => $this->nom_utilisateur,
            'nom_affiche' => $this->nom_affiche,
            'avatar' => $this->avatar ? Medias::public()->url($this->avatar) : null,
            'bio' => $this->bio,
            'site' => $this->site,
            'ville' => collect([$this->ville, $this->pays])->filter()->implode(', '),
            'compteurs' => [
                'contenus' => (int) ($this->nombre_publies ?? 0),
                // Son lifestyle, s'il l'a rendu visible : un bouton sur son profil.
                'lifestyle' => $this->lifestyle_visible ? (int) ($this->nombre_lifestyle ?? 0) : 0,
                'abonnes' => (int) $this->nombre_abonnes,
                'abonnements' => (int) $this->nombre_abonnements,
            ],
            // Ce que le membre connecté sait de lui : s'il le suit, s'il l'a bloqué.
            'moi' => $this->when($request->user('sanctum') !== null, fn () => [
                'abonne' => $request->user('sanctum')->suit($this->resource),
                'bloque' => $request->user('sanctum')->aBloque($this->resource),
                'c_est_moi' => $request->user('sanctum')->id === $this->id,
            ]),
        ];
    }
}
