<?php

namespace App\Services\Contenus;

/**
 * Les signes, dans le fichier lui-même, d'une image faite par une IA (ARCHITECTURE.md, 6.2) :
 *  - la marque de provenance IPTC (XMP ou C2PA) « trainedAlgorithmicMedia » ;
 *  - le logiciel de génération, inscrit par certains outils (EXIF « Software », XMP CreatorTool).
 * Ce n'est pas une preuve d'authenticité : c'est ce que le fichier avoue.
 */
class DetecteurIa
{
    private const MARQUES = [
        'trainedAlgorithmicMedia' => 'marque de provenance d’une image générée par une IA',
        'compositeWithTrainedAlgorithmicMedia' => 'marque de provenance d’une image retouchée par une IA',
        'algorithmicMedia' => 'marque de provenance d’une image de synthèse',
    ];

    private const LOGICIELS = ['midjourney', 'dall-e', 'dall·e', 'stable diffusion', 'stablediffusion', 'firefly', 'imagen', 'leonardo.ai', 'nightcafe', 'dreamstudio', 'comfyui', 'automatic1111', 'novelai', 'ideogram', 'flux.1'];

    /** Le motif, en français, si le fichier porte un signe d'IA ; sinon null. */
    public function motif(string $chemin): ?string
    {
        $taille = (int) @filesize($chemin);
        if ($taille === 0) {
            return null;
        }
        $f = fopen($chemin, 'rb');
        // Les métadonnées sont au début (EXIF, XMP) ou à la fin (certains C2PA) du fichier.
        $debut = (string) fread($f, 512 * 1024);
        $fin = '';
        if ($taille > 512 * 1024) {
            fseek($f, max(0, $taille - 128 * 1024));
            $fin = (string) fread($f, 128 * 1024);
        }
        fclose($f);
        $texte = $debut.$fin;

        foreach (self::MARQUES as $marque => $motif) {
            if (str_contains($texte, 'digitalsourcetype/'.$marque) || str_contains($texte, '"'.$marque.'"') || str_contains($texte, '>'.$marque.'<')) {
                return 'L’image porte une '.$motif.'.';
            }
        }
        $minuscule = strtolower($texte);
        foreach (self::LOGICIELS as $logiciel) {
            if (str_contains($minuscule, $logiciel)) {
                return 'L’image a été produite par un logiciel de génération ('.$logiciel.').';
            }
        }

        return null;
    }
}
