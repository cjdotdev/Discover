<?php

namespace App\Console\Commands;

use App\Models\Son;
use App\Services\Sons\Preparation;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Le catalogue des sons (database/sons/catalogue.json) : chaque morceau pas encore là est
 * téléchargé, ramené en AAC 128 kbit/s, envoyé sur R2 avec le dessin de son onde et son passage
 * le plus fort (Preparation). Au démarrage du serveur, à côté : ajouter un morceau au fichier suffit.
 */
#[Signature('usw:importer-sons {--catalogue= : Un autre fichier que database/sons/catalogue.json}')]
#[Description('Ajoute au catalogue les sons à mettre sur les reels')]
class ImporterSons extends Command
{
    public function handle(): int
    {
        if (! Preparation::disponible()) {
            $this->warn('ffmpeg manque : aucun son importé.');

            return self::SUCCESS;
        }
        $fichier = $this->option('catalogue') ?: database_path('sons/catalogue.json');
        $catalogue = json_decode((string) file_get_contents($fichier), true);
        $connus = Son::pluck('cle')->flip();
        $preparation = Preparation::creer();
        $faits = 0;
        foreach ($catalogue['sons'] ?? [] as $s) {
            if (isset($connus[$s['cle']])) {
                continue;
            }
            try {
                $this->importer($s, $preparation);
                $faits++;
            } catch (Throwable $e) {
                $this->warn("{$s['titre']} : {$e->getMessage()}");
            }
        }
        $this->info("{$faits} sons ajoutés.");

        return self::SUCCESS;
    }

    private function importer(array $s, Preparation $preparation): void
    {
        $dossier = Preparation::dossier();
        $brut = $dossier.'/'.md5($s['cle']).'.source';
        $sortie = $dossier.'/'.md5($s['cle']).'.m4a';
        try {
            Http::timeout(120)->retry(3, 2000)->sink($brut)->get($s['fichier'])->throw();
            $infos = $preparation->convertir($brut, $sortie);
            $preparation->publier(new Son([
                'cle' => $s['cle'],
                'titre' => $s['titre'],
                'artiste' => $s['artiste'],
                'categorie' => $s['categorie'],
                'duree_ms' => $infos['duree_ms'],
                'chemin' => '',
                'forme' => $infos['forme'],
                'debut_conseille_ms' => $infos['debut_ms'],
                'licence' => $s['licence'],
                'licence_url' => $s['licence_url'] ?? null,
                'attribution' => $s['attribution'],
            ]), $sortie);
        } finally {
            @unlink($brut);
            @unlink($sortie);
        }
    }
}
