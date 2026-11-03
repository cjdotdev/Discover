<?php

namespace App\Http\Resources;

use App\Models\Son;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Un son du catalogue : de quoi l'écouter, choisir son extrait (le dessin de l'onde, le passage
 * proposé) et citer son auteur comme sa licence le demande.
 *
 * @mixin Son
 */
class SonResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->ulid,
            'titre' => $this->titre,
            'artiste' => $this->artiste,
            'categorie' => $this->categorie,
            'duree_ms' => $this->duree_ms,
            'url' => $this->url(),
            'forme' => $this->forme ?? [],
            'debut_conseille_ms' => $this->debut_conseille_ms,
            'attribution' => $this->attribution,
            'licence' => $this->licence,
            'licence_url' => $this->licence_url,
            'nombre_reels' => $this->nombre_reels,
            'actif' => $this->actif,
            // Importé par un membre (pas du catalogue de Discover) : il peut être signalé.
            'importe' => $this->utilisateur_id !== null,
            // Dans mes favoris, quand la requête l'a demandé (membre connecté).
            'favori' => $this->when(array_key_exists('favori', $this->getAttributes()), fn () => (bool) $this->favori),
        ];
    }
}
