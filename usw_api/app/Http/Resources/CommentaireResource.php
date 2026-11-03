<?php

namespace App\Http\Resources;

use App\Models\Commentaire;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Un commentaire (E10) : son auteur, à qui il répond, ses « j'aime » et ses réponses.
 *
 * @mixin Commentaire
 */
class CommentaireResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $moi = $request->user('sanctum');

        return [
            'id' => $this->ulid,
            'texte' => $this->texte,
            'auteur' => new AuteurResource($this->whenLoaded('auteur')),
            'repond_a' => $this->whenLoaded('repondA', fn () => $this->repondA === null ? null : [
                'nom_utilisateur' => $this->repondA->nom_utilisateur,
                'nom_affiche' => $this->repondA->nom_affiche,
            ]),
            'parent' => $this->when($this->parent_id !== null, fn () => $this->relationLoaded('parent') ? $this->parent?->ulid : null),
            'epingle' => $this->epingle,
            // Écrit par l'auteur de la publication (la maquette le signale).
            'de_l_auteur' => $this->whenLoaded('contenu', fn () => $this->contenu->utilisateur_id === $this->utilisateur_id),
            'jaime' => $this->nombre_jaime,
            'reponses' => $this->nombre_reponses,
            'cree_le' => $this->created_at?->toIso8601String(),
            'modifie' => $this->updated_at !== null && $this->created_at !== null && $this->updated_at->gt($this->created_at->copy()->addSeconds(5)),
            'moi' => $this->when($moi !== null && array_key_exists('aime_par_moi', $this->getAttributes()), fn () => [
                'jaime' => (bool) $this->aime_par_moi,
                'auteur' => $moi->id === $this->utilisateur_id,
            ]),
        ];
    }
}
