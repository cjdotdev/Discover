<?php

namespace App\Support;

use App\Models\Contenu;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Storage;

/**
 * Les trois endroits où vivent les fichiers (config/discover.php) :
 *  - `travail` : le disque privé du serveur, le temps de recevoir et de vérifier un envoi ;
 *  - `public` : ce que tout le monde voit (Cloudflare R2 en production) ;
 *  - `originaux` : les originaux, seulement si on choisit de les garder.
 */
class Medias
{
    /**
     * Les fichiers publics se gardent 7 jours dans le cache de Cloudflare et du téléphone : servis
     * de près, ils arrivent bien plus vite. Pas plus : une publication supprimée ou retirée par la
     * modération ne doit pas rester servie longtemps.
     */
    public const CACHE = 'public, max-age=604800';

    public static function travail(): Filesystem
    {
        return Storage::disk('local');
    }

    public static function public(): Filesystem
    {
        return Storage::disk(config('discover.medias'));
    }

    public static function originaux(): Filesystem
    {
        return Storage::disk(config('discover.originaux'));
    }

    /** Tout ce qu'un contenu a laissé, partout. */
    public static function effacer(Contenu $contenu): void
    {
        $dossier = "contenus/{$contenu->ulid}";
        self::travail()->deleteDirectory($dossier);
        self::public()->deleteDirectory($dossier);
        if (config('discover.originaux') !== 'local') {
            self::originaux()->deleteDirectory($dossier);
        }
        foreach ($contenu->envois as $e) {
            self::travail()->delete($e->cheminPartiel());
        }
    }
}
