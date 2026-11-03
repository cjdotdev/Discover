<?php

namespace App\Services\Sons;

use App\Models\Son;
use App\Support\Medias;
use Illuminate\Support\Facades\Process;
use RuntimeException;

/**
 * Un son prêt pour les reels : ramené en AAC 128 kbit/s, avec le dessin de son onde et son passage
 * le plus fort, puis envoyé sur R2. Pour le catalogue (usw:importer-sons) comme pour un son
 * importé par un membre (POST sons).
 */
class Preparation
{
    /** Le passage proposé d'abord : les 30 secondes les plus fortes. */
    private const EXTRAIT_MS = 30_000;

    private const BARRES = 100;

    public function __construct(private readonly string $ffmpeg) {}

    public static function disponible(): bool
    {
        return (bool) config('services.ffmpeg.chemin');
    }

    public static function creer(): self
    {
        return new self((string) config('services.ffmpeg.chemin'));
    }

    /**
     * Convertit $source en AAC (sans image ni métadonnées) dans $sortie.
     *
     * @return array{duree_ms: int, forme: list<int>, debut_ms: int}
     */
    public function convertir(string $source, string $sortie): array
    {
        $r = Process::timeout(300)->run([$this->ffmpeg, '-y', '-i', $source, '-vn', '-map_metadata', '-1', '-c:a', 'aac', '-b:a', '128k', '-ac', '2', '-movflags', '+faststart', $sortie]);
        if (! $r->successful() || ! is_file($sortie) || filesize($sortie) === 0) {
            throw new RuntimeException('conversion impossible');
        }
        $duree = preg_match('/Duration: (\d+):(\d+):(\d+)\.(\d+)/', $r->errorOutput(), $m) === 1
            ? (((int) $m[1] * 60 + (int) $m[2]) * 60 + (int) $m[3]) * 1000 + (int) str_pad(substr($m[4], 0, 3), 3, '0')
            : 0;
        [$forme, $debut] = $this->forme($sortie, $duree);

        return ['duree_ms' => $duree, 'forme' => $forme, 'debut_ms' => $debut];
    }

    /** Le son converti part sur R2 (gardé un an : son adresse ne change jamais) ; le son est enregistré. */
    public function publier(Son $son, string $m4a): void
    {
        $son->ulid ??= $son->newUniqueId();
        $son->chemin = "sons/{$son->ulid}.m4a";
        $flux = fopen($m4a, 'rb');
        Medias::public()->writeStream($son->chemin, $flux, ['ContentType' => 'audio/mp4', 'CacheControl' => 'public, max-age=31536000, immutable']);
        if (is_resource($flux)) {
            fclose($flux);
        }
        $son->save();
    }

    /** Un dossier de travail pour les sons (hors du disque public). */
    public static function dossier(): string
    {
        $dossier = Medias::travail()->path('sons');
        if (! is_dir($dossier)) {
            mkdir($dossier, 0700, true);
        }

        return $dossier;
    }

    /**
     * Le dessin de l'onde (100 barres de 0 à 100), lu sur le son ramené à 2 000 échantillons par
     * seconde, et le début des 30 secondes les plus fortes (le refrain, souvent).
     *
     * @return array{0: list<int>, 1: int}
     */
    private function forme(string $son, int $dureeMs): array
    {
        $r = Process::timeout(120)->run([$this->ffmpeg, '-v', 'quiet', '-i', $son, '-ac', '1', '-ar', '2000', '-f', 's16le', '-']);
        $pcm = $r->output();
        $n = intdiv(strlen($pcm), 2);
        if ($n < self::BARRES) {
            return [array_fill(0, self::BARRES, 0), 0];
        }
        $echantillons = unpack('s*', $pcm);
        $parBarre = intdiv($n, self::BARRES);
        $energies = [];
        for ($b = 0; $b < self::BARRES; $b++) {
            $somme = 0.0;
            for ($i = 1 + $b * $parBarre, $fin = $i + $parBarre; $i < $fin; $i++) {
                $somme += $echantillons[$i] * $echantillons[$i];
            }
            $energies[] = sqrt($somme / $parBarre);
        }
        $max = max($energies) ?: 1;
        $forme = array_map(fn ($e) => (int) round($e / $max * 100), $energies);

        // La fenêtre de 30 s (en barres) la plus forte.
        $largeur = $dureeMs > 0 ? max(1, (int) round(self::EXTRAIT_MS / $dureeMs * self::BARRES)) : self::BARRES;
        $debut = 0;
        if ($largeur < self::BARRES) {
            $meilleure = -1.0;
            for ($b = 0; $b + $largeur <= self::BARRES; $b++) {
                $total = array_sum(array_slice($energies, $b, $largeur));
                if ($total > $meilleure) {
                    $meilleure = $total;
                    $debut = $b;
                }
            }
        }

        return [$forme, (int) round($debut / self::BARRES * $dureeMs)];
    }
}
