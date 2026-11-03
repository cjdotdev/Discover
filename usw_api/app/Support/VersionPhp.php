<?php

namespace App\Support;

/**
 * Les versions de PHP qui corrigent php2shell (CVE-2026-109618 et CVE-2026-109619),
 * ARCHITECTURE.md, section 9 : 8.5.12, 8.4.27, 8.3.36, 8.2.35 au minimum dans leur branche.
 */
class VersionPhp
{
    /** Pour chaque branche encore suivie, la première version corrigée. */
    public const CORRIGEES = [
        '8.5' => '8.5.12',
        '8.4' => '8.4.27',
        '8.3' => '8.3.36',
        '8.2' => '8.2.35',
    ];

    public static function estCorrigee(string $version): bool
    {
        if (! preg_match('/^(\d+)\.(\d+)\.(\d+)/', $version, $morceaux)) {
            return false;
        }
        $branche = $morceaux[1].'.'.$morceaux[2];

        // Une branche plus récente que toutes celles de la liste est corrigée d'office.
        if (version_compare($branche, array_key_first(self::CORRIGEES), '>')) {
            return true;
        }

        $minimum = self::CORRIGEES[$branche] ?? null;

        return $minimum !== null && version_compare($morceaux[0], $minimum, '>=');
    }
}
