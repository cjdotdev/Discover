<?php

namespace App\Console\Commands;

use App\Models\Localite;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use ZipArchive;

/**
 * Les villes et villages de plus de 1 000 habitants, de GeoNames (licence CC BY 4.0) : environ
 * 160 000 lignes. Au démarrage du serveur, seulement si la table est vide (--si-vide).
 */
#[Signature('usw:importer-localites {--si-vide : Ne rien faire si les localités sont déjà là} {--fichier= : Un cities1000.zip déjà téléchargé} {--regions= : Un admin1CodesASCII.txt déjà téléchargé}')]
#[Description('Importe les villes du monde (GeoNames) pour le choix de la ville du profil')]
class ImporterLocalites extends Command
{
    private const VILLES = 'https://download.geonames.org/export/dump/cities1000.zip';

    private const REGIONS = 'https://download.geonames.org/export/dump/admin1CodesASCII.txt';

    /** Les lieux habités qui n'existent plus ou ne sont qu'une partie d'une ville. */
    private const ECARTES = ['PPLX', 'PPLH', 'PPLQ', 'PPLW', 'PPLCH'];

    public function handle(): int
    {
        if ($this->option('si-vide') && Localite::query()->exists()) {
            return self::SUCCESS;
        }
        $zip = $this->option('fichier') ?: $this->telecharger(self::VILLES, 'cities1000.zip');
        $regions = $this->regions($this->option('regions') ?: $this->telecharger(self::REGIONS, 'admin1CodesASCII.txt'));

        $archive = new ZipArchive;
        if ($archive->open($zip) !== true) {
            throw new RuntimeException('Le fichier des villes est illisible.');
        }
        $flux = $archive->getStream('cities1000.txt');
        if ($flux === false) {
            throw new RuntimeException('cities1000.txt manque dans le fichier.');
        }

        $lot = [];
        $n = 0;
        while (($ligne = fgets($flux)) !== false) {
            $c = explode("\t", rtrim($ligne, "\r\n"));
            if (count($c) < 15 || in_array($c[7], self::ECARTES, true)) {
                continue;
            }
            $lot[] = [
                'geoname_id' => (int) $c[0],
                'pays' => $c[8],
                'nom' => mb_substr($c[1], 0, 200),
                'recherche' => mb_substr(Localite::normaliser($c[2] !== '' ? $c[2] : $c[1]), 0, 200),
                'region' => $regions["{$c[8]}.{$c[10]}"] ?? null,
                'population' => min((int) $c[14], 4_000_000_000),
                'latitude' => round((float) $c[4], 6),
                'longitude' => round((float) $c[5], 6),
            ];
            if (count($lot) === 1000) {
                $n += $this->ranger($lot);
                $lot = [];
            }
        }
        $n += $this->ranger($lot);
        fclose($flux);
        $archive->close();
        $this->info("{$n} localités importées.");

        return self::SUCCESS;
    }

    private function ranger(array $lot): int
    {
        if ($lot !== []) {
            DB::table('localites')->upsert($lot, ['geoname_id'], ['pays', 'nom', 'recherche', 'region', 'population', 'latitude', 'longitude']);
        }

        return count($lot);
    }

    /** @return array<string, string> « BJ.10 » → « Littoral » */
    private function regions(string $chemin): array
    {
        $regions = [];
        foreach (file($chemin, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $ligne) {
            $c = explode("\t", $ligne);
            if (count($c) >= 2) {
                $regions[$c[0]] = mb_substr($c[1], 0, 120);
            }
        }

        return $regions;
    }

    private function telecharger(string $url, string $nom): string
    {
        $chemin = storage_path("app/private/{$nom}");
        @mkdir(dirname($chemin), 0775, true);
        $r = Http::timeout(300)->sink($chemin)->get($url);
        if (! $r->successful()) {
            throw new RuntimeException("GeoNames ne répond pas ({$r->status()}).");
        }

        return $chemin;
    }
}
