<?php

namespace App\Http\Resources;

use App\Models\Contenu;
use App\Models\Variante;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Une photo ou un reel (E05, E06). Les images : une adresse par taille, et la largeur et la
 * hauteur, pour réserver la place avant qu'elles arrivent. Le fichier original n'en sort jamais.
 *
 * @mixin Contenu
 */
class ContenuResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->ulid,
            'type' => $this->type->value,
            // lifestyle : une publication du lifestyle de son auteur (hors de l'accueil).
            'portee' => $this->portee ?? 'decouverte',
            'badge' => $this->badge?->value,
            'titre' => $this->titre,
            'legende' => $this->legende,
            'duree' => $this->duree,
            'son' => $this->son,
            // La musique du catalogue : sa page (les reels qui l'utilisent, « Utiliser ce son »).
            'musique' => $this->son_id === null ? null : (function () {
                $s = $this->resource->loadMissing('musique')->musique;

                return $s === null ? null : ['id' => $s->ulid, 'titre' => $s->titre, 'artiste' => $s->artiste, 'actif' => $s->actif];
            })(),
            'ratio' => $this->ratio(),
            'publie_le' => $this->publie_le?->toIso8601String(),
            // L'auteur peut la modifier jusque-là (1 h après sa mise en ligne) ; ensuite, la supprimer seulement.
            'modifiable_jusqu_au' => $this->estPublie() && $this->publie_le ? $this->publie_le->copy()->addMinutes(Contenu::DELAI_MODIFICATION_MINUTES)->toIso8601String() : null,
            // Le statut ne regarde que l'auteur (son brouillon, un refus).
            'statut' => $this->when($request->user('sanctum')?->id === $this->utilisateur_id, fn () => $this->statut->value),
            'motif' => $this->when($request->user('sanctum')?->id === $this->utilisateur_id, fn () => $this->motif),
            'manque' => $this->when($request->user('sanctum')?->id === $this->utilisateur_id, fn () => $this->manque ?? []),
            // Une seconde vérification déjà demandée (une seule par publication refusée).
            'recours' => $this->when($request->user('sanctum')?->id === $this->utilisateur_id, fn () => $this->recours_le !== null),
            'auteur' => new AuteurResource($this->whenLoaded('auteur')),
            // Le nom donné sans position (« Chez ma grand-mère ») : la photo est dans « Sans lieu ».
            'nom_lieu' => $this->nom_lieu,
            'lieu' => $this->whenLoaded('lieu', fn () => $this->lieu === null ? null : [
                'id' => $this->lieu->slug,
                'nom' => $this->lieu->nom,
                'region' => $this->lieu->relationLoaded('ville') ? $this->lieu->region() : null,
                'latitude' => $this->lieu->latitude,
                'longitude' => $this->lieu->longitude,
                'situe' => $this->lieu->estSitue(),
            ]),
            'capture' => $this->whenLoaded('capture', fn () => $this->capture === null ? null : [
                'source' => $this->capture->source->value,
                'telephone' => $this->capture->relationLoaded('modele') ? $this->capture->modele?->complet() : null,
                'prise_le' => $this->capture->prise_le?->toIso8601String(),
                'latitude' => $this->positionPublique() ? $this->capture->latitude : null,
                'longitude' => $this->positionPublique() ? $this->capture->longitude : null,
                'origines' => $this->capture->origines ?? (object) [],
            ]),
            'images' => $this->whenLoaded('variantes', fn () => $this->variantes->mapWithKeys(fn (Variante $v) => [
                $v->usage->value => ['url' => $v->url(), 'largeur' => $v->largeur, 'hauteur' => $v->hauteur],
            ])),
            // Ce que le membre connecté en dit, quand la requête l'a chargé (scope avecMoi).
            'moi' => $this->when(array_key_exists('ma_reaction', $this->getAttributes()), fn () => [
                'reaction' => $this->ma_reaction,
                'enregistre' => (int) $this->enregistre_par_moi > 0,
            ]),
            'compteurs' => [
                'reactions' => $this->nombre_reactions,
                'commentaires' => $this->nombre_commentaires,
                'enregistrements' => $this->nombre_enregistrements,
                'partages' => $this->nombre_partages,
                'vues' => (int) $this->nombre_vues,
            ],
        ];
    }

    /**
     * La position de la prise se montre, sauf pour une photo de la pile « Sans lieu » (la
     * publication ne la garde d'ailleurs pas : rien ne la trahit, relation chargée ou non).
     */
    private function positionPublique(): bool
    {
        return ! $this->relationLoaded('lieu') || $this->lieu === null || $this->lieu->estSitue();
    }
}
