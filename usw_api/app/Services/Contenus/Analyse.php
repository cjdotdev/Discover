<?php

namespace App\Services\Contenus;

use App\Enums\Badge;
use App\Enums\StatutContenu;
use App\Models\Contenu;

/**
 * B32 : la décision, sans écran pour le membre (ARCHITECTURE.md, section 6.2).
 *  - un signe d'IA dans le fichier : refusé, avec le motif ;
 *  - une information manquante (téléphone, date, lieu) : à compléter (E15, E30) ;
 *  - une incohérence (date dans le futur, position impossible) : file humaine ;
 *  - sinon publié, « Capture vérifiée » si tout vient du fichier ou de l'appareil photo,
 *    « Informations déclarées » sinon.
 */
class Analyse
{
    public function __construct(private DetecteurIa $ia) {}

    /** @return array{statut: StatutContenu, motif: ?string, manque: list<string>, badge: ?Badge, origines: array<string, string>} */
    public function decider(Contenu $contenu, ?string $fichierPrincipal, ?string $original): array
    {
        $capture = $contenu->capture;
        $origines = $capture?->origines ?? [];

        foreach (array_filter([$original, $fichierPrincipal]) as $f) {
            if ($motif = $this->ia->motif($f)) {
                return ['statut' => StatutContenu::Refuse, 'motif' => $motif, 'manque' => [], 'badge' => null, 'origines' => $origines];
            }
        }

        // Ce que l'application dit avoir lu dans le fichier (« exif ») est relu : une photo
        // JPEG sans aucune donnée EXIF ne peut pas l'avoir fourni.
        if ($original && str_ends_with($original, '.jpg') && function_exists('exif_read_data')) {
            $exif = @exif_read_data($original) ?: [];
            $lu = isset($exif['Model']) || isset($exif['DateTimeOriginal']) || isset($exif['GPSLatitude']);
            if (! $lu) {
                foreach ($origines as $champ => $origine) {
                    if ($origine === 'exif') {
                        $origines[$champ] = 'declaree';
                    }
                }
            }
        }

        $manque = [];
        if ($capture?->modele_telephone_id === null) {
            $manque[] = 'telephone';
        }
        if ($capture?->prise_le === null) {
            $manque[] = 'date';
        }
        if ($manque) {
            return ['statut' => StatutContenu::ACompleter, 'motif' => 'Il manque des informations sur la prise.', 'manque' => $manque, 'badge' => null, 'origines' => $origines];
        }

        if ($capture->prise_le->isAfter(now()->addDay())) {
            return ['statut' => StatutContenu::FileHumaine, 'motif' => 'La date de prise est dans le futur.', 'manque' => [], 'badge' => null, 'origines' => $origines];
        }
        if ($capture->latitude !== null && abs($capture->latitude) < 0.0001 && abs((float) $capture->longitude) < 0.0001) {
            return ['statut' => StatutContenu::FileHumaine, 'motif' => 'La position de prise est impossible.', 'manque' => [], 'badge' => null, 'origines' => $origines];
        }

        $verifie = collect(['modele', 'date', 'position'])
            ->every(fn ($champ) => in_array($origines[$champ] ?? 'declaree', ['exif', 'appareil'], true));

        return ['statut' => StatutContenu::Publie, 'motif' => null, 'manque' => [], 'badge' => $verifie ? Badge::Verifiee : Badge::Declaree, 'origines' => $origines];
    }
}
