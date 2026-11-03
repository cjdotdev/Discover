<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;

/**
 * Les langues que le serveur parle : le français (la langue des textes du code), et chaque
 * paquet de resources/langues/{code}.json (les mêmes que l'application télécharge).
 */
final class Langues
{
    public const SOURCE = 'fr';

    /** @return list<string> */
    public static function connues(): array
    {
        return Cache::remember('langues:connues', 600, fn () => array_values(array_unique([
            self::SOURCE,
            ...array_map(fn ($f) => basename($f, '.json'), glob(resource_path('langues').'/*.json') ?: []),
        ])));
    }

    /** « sw-KE,sw;q=0.9,fr;q=0.8 » → « sw » si elle est connue ; sinon nul. */
    public static function choisir(?string $entete): ?string
    {
        foreach (explode(',', (string) $entete) as $morceau) {
            $code = strtolower(substr(trim(explode(';', $morceau)[0]), 0, 3));
            $code = rtrim(explode('-', str_replace('_', '-', $code))[0], '-');
            if ($code !== '' && in_array($code, self::connues(), true)) {
                return $code;
            }
        }

        return null;
    }

    /** Les traductions d'une langue : le texte français → sa traduction. */
    public static function textes(string $code): array
    {
        if ($code === self::SOURCE || preg_match('/^[a-z]{2,3}$/', $code) !== 1) {
            return [];
        }
        $f = resource_path("langues/{$code}.json");
        if (! is_file($f)) {
            return [];
        }

        return Cache::remember("langues:textes:{$code}:".filemtime($f), 3600, function () use ($f) {
            $j = json_decode((string) file_get_contents($f), true);

            return is_array($j['textes'] ?? null) ? $j['textes'] : [];
        });
    }
}
