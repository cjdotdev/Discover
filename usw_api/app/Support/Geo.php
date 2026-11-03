<?php

namespace App\Support;

/** La distance entre deux points du globe (formule de haversine), en kilomètres. */
final class Geo
{
    public const RAYON_TERRE_KM = 6371.0088;

    public static function distanceKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) ** 2;

        return 2 * self::RAYON_TERRE_KM * asin(min(1.0, sqrt($a)));
    }

    /**
     * Le rectangle qui contient le cercle (pour l'index de la base) : [latMin, latMax, lonMin, lonMax].
     *
     * @return array{float, float, float, float}
     */
    public static function rectangle(float $lat, float $lon, float $rayonKm): array
    {
        $dLat = rad2deg($rayonKm / self::RAYON_TERRE_KM);
        $dLon = rad2deg($rayonKm / (self::RAYON_TERRE_KM * max(cos(deg2rad($lat)), 0.01)));

        return [$lat - $dLat, $lat + $dLat, $lon - $dLon, $lon + $dLon];
    }
}
