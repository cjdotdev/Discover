<?php

namespace App\Http\Resources;

use App\Models\Lieu;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Un lieu, comme l'application l'affiche (E33, la pile de l'accueil).
 *
 * @mixin Lieu
 */
class LieuResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->slug,
            'nom' => $this->nom,
            'type' => $this->type,
            'region' => $this->whenLoaded('ville', fn () => $this->region()),
            'ville' => $this->whenLoaded('ville', fn () => $this->ville?->nom),
            'pays' => $this->whenLoaded('ville', fn () => $this->ville?->pays?->nom),
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            // Faux pour la pile « Sans lieu » : pas de carte, pas de distance.
            'situe' => $this->estSitue(),
            'nombre_contenus' => $this->nombre_contenus,
            'nombre_reels' => $this->nombre_reels ?? 0,
            // Les publications au badge « Capture vérifiée » : le filtre de la recherche et de la carte.
            'nombre_verifiees' => $this->nombre_verifiees ?? 0,
            // Seulement sur la page du lieu, pour un membre connecté.
            'enregistre' => $this->when(array_key_exists('enregistre', $this->getAttributes()), fn () => (bool) $this->getAttributes()['enregistre']),
            // Les 4 meilleures photos : la pile, la première devant.
            'photos' => ContenuResource::collection($this->whenLoaded('meilleures')),
        ];
    }
}
