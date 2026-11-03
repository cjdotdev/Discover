<?php

namespace App\Support;

use RuntimeException;

/** Avant de décoder une image : ses dimensions, lues sans la décoder. 50 mégapixels au plus. */
final class Dimensions
{
    public const MAX_PIXELS = 50_000_000;

    public const MAX_COTE = 12_000;

    /** Assez petite pour être décodée (une image illisible ainsi, comme HEIC, compte comme acceptable). */
    public static function acceptable(string $chemin): bool
    {
        $taille = @getimagesize($chemin);

        return $taille === false || ($taille[0] <= self::MAX_COTE && $taille[1] <= self::MAX_COTE && $taille[0] * $taille[1] <= self::MAX_PIXELS);
    }

    public static function verifier(string $chemin): void
    {
        if (! self::acceptable($chemin)) {
            throw new RuntimeException('Image trop grande.');
        }
    }
}
