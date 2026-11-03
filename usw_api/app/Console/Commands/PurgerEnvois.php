<?php

namespace App\Console\Commands;

use App\Enums\StatutContenu;
use App\Enums\StatutEnvoi;
use App\Http\Controllers\Api\V1\ContenuController;
use App\Models\Contenu;
use App\Models\Envoi;
use App\Models\FichierOriginal;
use App\Support\Medias;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Chaque nuit (B35) : les envois abandonnés depuis 7 jours, leur fichier partiel, et les
 * brouillons qui n'ont jamais reçu de fichier.
 */
#[Signature('usw:purger-envois')]
#[Description('Supprime les envois abandonnés depuis plus de 7 jours')]
class PurgerEnvois extends Command
{
    public function handle(): int
    {
        $limite = now()->subDays(7);
        $n = 0;
        Envoi::where('statut', StatutEnvoi::EnCours)->where('derniere_activite', '<', $limite)->with('contenu.envois')->chunkById(100, function ($envois) use (&$n) {
            foreach ($envois as $e) {
                Medias::travail()->delete($e->cheminPartiel());
                $contenu = $e->contenu;
                $e->delete();
                $n++;
                // Une publication restée incomplète (brouillon, à compléter, à revoir) ne sera plus finie.
                if ($contenu && $contenu->statut !== StatutContenu::Publie && $contenu->statut !== StatutContenu::Refuse) {
                    Medias::travail()->deleteDirectory("contenus/{$contenu->ulid}");
                    $contenu->delete();
                }
            }
        });
        // Une publication refusée garde ses fichiers 30 jours : le temps d'une seconde vérification.
        $refus = 0;
        Contenu::where('statut', StatutContenu::Refuse)
            ->whereBetween('updated_at', [now()->subDays(ContenuController::DELAI_RECOURS_JOURS + 10), now()->subDays(ContenuController::DELAI_RECOURS_JOURS)])
            ->select(['id', 'ulid'])->chunkById(100, function ($contenus) use (&$refus) {
                foreach ($contenus as $c) {
                    Medias::travail()->deleteDirectory("contenus/{$c->ulid}");
                    FichierOriginal::where('contenu_id', $c->id)->whereNotNull('chemin')->update(['chemin' => null]);
                    $refus++;
                }
            });
        $this->info("{$n} envoi(s) abandonné(s) supprimé(s), {$refus} dossier(s) refusé(s) vidé(s).");

        return self::SUCCESS;
    }
}
