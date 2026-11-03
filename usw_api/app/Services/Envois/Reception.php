<?php

namespace App\Services\Envois;

use App\Enums\RoleEnvoi;
use App\Enums\StatutEnvoi;
use App\Enums\TypeContenu;
use App\Exceptions\ErreurMetier;
use App\Models\Envoi;
use App\Models\FichierOriginal;
use App\Support\Medias;
use Illuminate\Validation\ValidationException;

/**
 * B30 : les morceaux d'un fichier, à la suite, sur le disque privé (protocole inspiré de tus).
 * Un morceau qui ne commence pas là où le précédent s'est arrêté est refusé (409) :
 * l'application redemande où on en est (HEAD) et reprend de là.
 */
class Reception
{
    /** 4 Mo au plus par morceau : l'application envoie de 256 Ko (3G) à 2 Mo (Wi-Fi). */
    public const MORCEAU_MAX = 4 * 1024 * 1024;

    /** Ce que l'on accepte, d'après la signature du fichier (pas son nom). */
    public const TYPES = [
        RoleEnvoi::Apercu->value => ['image/webp', 'image/jpeg', 'image/png'],
        'original_photo' => ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'image/avif'],
        'original_reel' => ['video/mp4', 'video/quicktime', 'video/3gpp'],
    ];

    private function disque()
    {
        return Medias::travail();
    }

    public function ajouter(Envoi $envoi, int $decalage, string $octets): Envoi
    {
        if ($envoi->estTermine()) {
            throw new ErreurMetier(409, 'Cet envoi est déjà complet.');
        }
        if ($decalage !== $envoi->recu) {
            throw new ErreurMetier(409, 'Le morceau ne suit pas le précédent.');
        }
        $n = strlen($octets);
        if ($n === 0) {
            throw new ErreurMetier(400, 'Morceau vide.');
        }
        if ($n > self::MORCEAU_MAX || $envoi->recu + $n > $envoi->taille) {
            throw new ErreurMetier(413, 'Le fichier est trop gros.');
        }
        $chemin = $this->disque()->path($envoi->cheminPartiel());
        if (! is_dir(dirname($chemin))) {
            mkdir(dirname($chemin), 0700, true);
        }
        // Le fichier partiel peut être plus long que ce qui a été compté (une coupure pendant
        // l'écriture) : on le recoupe d'abord au dernier décalage connu.
        $f = fopen($chemin, 'c+b');
        flock($f, LOCK_EX);
        ftruncate($f, $envoi->recu);
        fseek($f, $envoi->recu);
        fwrite($f, $octets);
        fflush($f);
        flock($f, LOCK_UN);
        fclose($f);

        $envoi->update(['recu' => $envoi->recu + $n, 'derniere_activite' => now()]);

        return $envoi;
    }

    /**
     * Le fichier est complet : son empreinte et son type sont vérifiés, puis il est rangé.
     * Renvoie le chemin définitif sur le disque privé.
     */
    public function terminer(Envoi $envoi): string
    {
        if ($envoi->estTermine()) {
            return $this->cheminFinal($envoi, $envoi->contenu->original?->format ?? 'bin');
        }
        if ($envoi->recu !== $envoi->taille) {
            throw new ErreurMetier(409, 'Il manque encore des morceaux.');
        }
        $partiel = $this->disque()->path($envoi->cheminPartiel());
        if (! hash_equals($envoi->empreinte_sha256, (string) hash_file('sha256', $partiel))) {
            // Le fichier s'est abîmé en route : on repart de zéro.
            @unlink($partiel);
            $envoi->update(['recu' => 0]);
            throw ValidationException::withMessages(['fichier' => 'Le fichier est arrivé abîmé. Il va repartir depuis le début.']);
        }
        $type = (string) (new \finfo(FILEINFO_MIME_TYPE))->file($partiel);
        $permis = $envoi->role === RoleEnvoi::Apercu
            ? self::TYPES['apercu']
            : self::TYPES[$envoi->contenu->type === TypeContenu::Reel ? 'original_reel' : 'original_photo'];
        if (! in_array($type, $permis, true)) {
            @unlink($partiel);
            $envoi->update(['recu' => 0]);
            throw ValidationException::withMessages(['fichier' => 'Ce fichier n’est pas une photo ou une vidéo acceptée.']);
        }
        $extension = self::extension($type);
        $final = $this->cheminFinal($envoi, $extension);
        $this->disque()->makeDirectory(dirname($final));
        rename($partiel, $this->disque()->path($final));
        $envoi->update(['statut' => StatutEnvoi::Termine, 'type' => $type, 'derniere_activite' => now()]);

        if ($envoi->role === RoleEnvoi::Original) {
            [$largeur, $hauteur] = self::dimensions($this->disque()->path($final));
            FichierOriginal::create([
                'contenu_id' => $envoi->contenu_id,
                'empreinte_sha256' => $envoi->empreinte_sha256,
                'format' => $extension,
                'largeur' => $largeur,
                'hauteur' => $hauteur,
                'poids' => $envoi->taille,
                'chemin' => $final,
            ]);
        }

        return $final;
    }

    public function cheminFinal(Envoi $envoi, string $extension): string
    {
        return "contenus/{$envoi->contenu->ulid}/{$envoi->role->value}.{$extension}";
    }

    public static function extension(string $type): string
    {
        return match ($type) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            'image/heic', 'image/heif' => 'heic',
            'image/avif' => 'avif',
            'video/mp4' => 'mp4',
            'video/quicktime' => 'mov',
            'video/3gpp' => '3gp',
            default => 'bin',
        };
    }

    /** @return array{?int, ?int} */
    public static function dimensions(string $chemin): array
    {
        $info = @getimagesize($chemin);

        return $info ? [$info[0], $info[1]] : [null, null];
    }
}
