<?php

namespace App\Http\Resources;

use App\Models\Utilisateur;
use App\Support\Medias;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Le membre connecté, tel que l'application le garde (GET moi). Jamais son numéro, son mot de
 * passe, ni son identifiant Google.
 *
 * @mixin Utilisateur
 */
class UtilisateurResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->ulid,
            'email' => $this->email,
            'fournisseur' => $this->fournisseur,
            // Lié à Google : il entre avec Google, et son adresse est celle de Google.
            'google' => $this->google_sub !== null,
            'nom_affiche' => $this->nom_affiche,
            'nom_utilisateur' => $this->nom_utilisateur,
            'bio' => $this->bio,
            'site' => $this->site,
            'pays' => $this->pays,
            'ville' => $this->ville,
            'position' => $this->position,
            'types_aimes' => $this->types_aimes ?? [],
            'avatar' => $this->avatar ? Medias::public()->url($this->avatar) : null,
            'profil_complete' => $this->profil_complete_le !== null,
            'compteurs' => [
                'abonnes' => (int) $this->nombre_abonnes,
                'abonnements' => (int) $this->nombre_abonnements,
                'contenus' => $this->contenus()->publies()->count(),
            ],
            'cree_le' => $this->created_at?->toIso8601String(),
        ];
    }
}
