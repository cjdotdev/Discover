<?php

namespace App\Services\Lieux;

use App\Models\Lieu;

/** Le lieu connu le plus proche d'une position, et sa distance. */
final readonly class Rapprochement
{
    public function __construct(public Lieu $lieu, public float $distanceKm) {}
}
