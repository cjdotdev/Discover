<?php

namespace App\Services\Lieux;

use App\Models\Lieu;
use App\Support\Geo;

/**
 * B25 : des coordonnées (lues dans la photo, ou celles du téléphone) vers le lieu connu le plus
 * proche, dans un rayon borné. Au-delà, la photo n'est rattachée à aucun lieu : on demandera.
 *
 * La base filtre d'abord par un rectangle (index latitude, longitude), puis la vraie distance
 * départage les quelques candidats.
 */
class RapprocheurLieu
{
    /** Le rayon par défaut : une plage, un parc s'étendent ; au-delà de 2 km, c'est un autre endroit. */
    public const RAYON_KM = 2.0;

    public function proche(float $latitude, float $longitude, float $rayonKm = self::RAYON_KM): ?Rapprochement
    {
        [$latMin, $latMax, $lonMin, $lonMax] = Geo::rectangle($latitude, $longitude, $rayonKm);

        return Lieu::query()
            ->whereBetween('latitude', [$latMin, $latMax])
            ->whereBetween('longitude', [$lonMin, $lonMax])
            ->get()
            ->map(fn (Lieu $l) => new Rapprochement($l, Geo::distanceKm($latitude, $longitude, $l->latitude, $l->longitude)))
            ->filter(fn (Rapprochement $r) => $r->distanceKm <= $rayonKm)
            ->sortBy(fn (Rapprochement $r) => $r->distanceKm)
            ->first();
    }
}
