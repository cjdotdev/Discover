<?php

namespace App\Jobs;

use App\Enums\Badge;
use App\Enums\RoleEnvoi;
use App\Enums\StatutContenu;
use App\Enums\TypeContenu;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use App\Services\Contenus\Analyse;
use App\Services\Contenus\Recommandation;
use App\Services\Contenus\Variantes;
use App\Support\Dimensions;
use App\Support\Medias;
use Illuminate\Contracts\Queue\ShouldBeUniqueUntilProcessing;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Throwable;

/**
 * Quand les fichiers d'un contenu sont arrivés : la décision (B32), puis, s'il est publié,
 * ses tailles d'image et sa vidéo (B33, B34). Relancé quand l'original arrive après
 * l'aperçu (une 2 160 px plus nette, et l'original relu à son tour).
 */
class AnalyserCapture implements ShouldBeUniqueUntilProcessing, ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    /** Plus court que celui de l'ouvrier (600 s) : une vidéo coincée ne le bloque pas. */
    public int $timeout = 540;

    /** Une seule analyse en attente par contenu : les demandes répétées ne s'empilent pas. */
    public int $uniqueFor = 900;

    public function uniqueId(): string
    {
        return (string) $this->contenu->id;
    }

    /** Trois échecs (une vidéo que ffmpeg ne lit pas) : l'équipe la revoit, rien de brut n'est publié. */
    public function failed(?Throwable $e): void
    {
        $c = $this->contenu->fresh();
        if ($c !== null && $c->statut !== StatutContenu::Publie) {
            $c->update(['statut' => StatutContenu::FileHumaine, 'motif' => 'Le fichier n’a pas pu être préparé.']);
        }
    }

    /** `$decisionHumaine` : un administrateur a décidé de publier, l'analyse ne tranche plus. */
    public function __construct(public Contenu $contenu, public bool $decisionHumaine = false) {}

    public function handle(Analyse $analyse, Variantes $variantes): void
    {
        $c = $this->contenu->fresh(['capture', 'envois']);
        if ($c === null || in_array($c->statut, [StatutContenu::Refuse, StatutContenu::FileHumaine], true)) {
            return;
        }
        $disque = Medias::travail();
        $fichier = function (RoleEnvoi $role) use ($c, $disque): ?string {
            $e = $c->envois->firstWhere('role', $role);
            if ($e === null || ! $e->estTermine()) {
                return null;
            }
            foreach ($disque->files("contenus/{$c->ulid}") as $f) {
                if (str_starts_with(basename($f), $role->value.'.')) {
                    return $disque->path($f);
                }
            }

            return null;
        };
        $apercu = $fichier(RoleEnvoi::Apercu);
        $original = $fichier(RoleEnvoi::Original);

        $d = $this->decisionHumaine
            ? ['statut' => StatutContenu::Publie, 'motif' => null, 'manque' => [], 'badge' => Badge::Verifiee, 'origines' => $c->capture?->origines ?? []]
            : $analyse->decider($c, $apercu, $original);
        $c->capture?->update(['origines' => $d['origines']]);

        if ($d['statut'] !== StatutContenu::Publie) {
            $c->update(['statut' => $d['statut'], 'motif' => $d['motif'], 'manque' => $d['manque'] ?: null, 'badge' => null]);
            if ($d['statut'] === StatutContenu::Refuse) {
                Activite::a(Utilisateur::find($c->utilisateur_id), new Activite('refusee', 'Votre publication n’a pas été acceptée. Motif : :motif', null, $c, valeurs: ['motif' => $d['motif']]));
            }

            // Refusé, à compléter ou à revoir : les fichiers attendent. Un refus peut être revu par
            // l'équipe si l'auteur le demande (30 jours) ; usw:purger-envois les efface ensuite.
            return;
        }

        // Les images d'abord : un contenu publié a toujours de quoi s'afficher.
        // Un original de plus de 50 Mpx (capteur de 108 ou 200 Mpx) n'est pas décodé : l'aperçu suffit.
        $image = $c->type === TypeContenu::Photo && $original && ! str_ends_with($original, '.heic') && Dimensions::acceptable($original) ? $original : $apercu;
        if ($image) {
            $variantes->images($c, $image);
        }
        if ($c->type === TypeContenu::Reel && $original) {
            $variantes->video($c, $original);
        }
        $premiere = $c->publie_le === null;
        $c->update([
            'statut' => StatutContenu::Publie,
            'motif' => null,
            'manque' => null,
            'badge' => $d['badge'],
            'publie_le' => $c->publie_le ?? now(),
        ]);
        Recommandation::noter($c);

        if ($premiere) {
            // Le texte suit le badge : « vérifiée » seulement pour une capture vérifiée.
            Activite::a(Utilisateur::find($c->utilisateur_id), new Activite('publiee', Activite::textePubliee($d['badge']), null, $c));
            PrevenirAbonnes::dispatch($c);
        }

        // Tout est arrivé : les fichiers de travail n'ont plus rien à faire sur le serveur.
        if ($c->envois->every(fn ($e) => $e->estTermine())) {
            $this->ranger($c, $original);
        }
    }

    /**
     * L'original va sur le disque des originaux si on les garde ; sinon il reste seulement sur le
     * téléphone de son auteur. L'aperçu et le reste du dossier de travail sont effacés.
     */
    private function ranger(Contenu $c, ?string $original): void
    {
        $fichier = $c->original()->first();
        $garder = config('discover.garder_originaux') && $c->statut !== StatutContenu::Refuse;
        if ($fichier !== null && $fichier->chemin !== null && $original !== null) {
            if ($garder && config('discover.originaux') !== 'local') {
                $flux = fopen($original, 'rb');
                Medias::originaux()->writeStream($fichier->chemin, $flux);
                if (is_resource($flux)) {
                    fclose($flux);
                }
            } elseif (! $garder) {
                $fichier->update(['chemin' => null]);
            }
        }
        if (! $garder || config('discover.originaux') !== 'local') {
            Medias::travail()->deleteDirectory("contenus/{$c->ulid}");
        } else {
            // Gardés sur ce disque même : seul l'aperçu part.
            foreach (Medias::travail()->files("contenus/{$c->ulid}") as $f) {
                if (! str_starts_with(basename($f), 'original.')) {
                    Medias::travail()->delete($f);
                }
            }
        }
    }
}
