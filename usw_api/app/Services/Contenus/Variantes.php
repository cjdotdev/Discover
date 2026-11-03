<?php

namespace App\Services\Contenus;

use App\Enums\TypeContenu;
use App\Enums\UsageVariante;
use App\Models\Contenu;
use App\Support\Dimensions;
use App\Support\Medias;
use Illuminate\Support\Facades\Process;
use RuntimeException;
use Throwable;

/**
 * B33 et B34 : ce que le public reçoit. Les photos en WebP (32 px pour le flou d'attente,
 * 480, 1 080, 2 160 et 3 840 px, la 4K), sans aucune métadonnée (GD n'en écrit pas) ; jamais
 * agrandies. Un reel : sa vidéo ré-encodée (H.264, son AAC) en 720p et, si la source est plus
 * grande, en 1080p, si ffmpeg est là, sinon telle quelle ; et son affiche, depuis l'aperçu.
 */
class Variantes
{
    private const TAILLES = [
        UsageVariante::Flou->value => [32, 40],
        UsageVariante::Petite->value => [480, 80],
        UsageVariante::Ecran->value => [1080, 82],
        UsageVariante::Grande->value => [2160, 84],
        UsageVariante::TresGrande->value => [3840, 86],
    ];

    /** Depuis l'aperçu (ou l'original d'une photo, plus grand, quand il est arrivé). */
    public function images(Contenu $contenu, string $source): void
    {
        $image = $this->ouvrir($source);
        $largeur = imagesx($image);
        $hauteur = imagesy($image);
        $contenu->update(['largeur' => $largeur, 'hauteur' => $hauteur]);
        $usages = $contenu->type === TypeContenu::Reel
            ? [UsageVariante::Flou->value => [32, 40], UsageVariante::Affiche->value => [1080, 82]]
            : self::TAILLES;
        foreach ($usages as $usage => [$cote, $qualite]) {
            // Jamais agrandie : une 2 160 ou une 3 840 px faite d'une image plus petite n'apporte rien.
            if (in_array($usage, [UsageVariante::Grande->value, UsageVariante::TresGrande->value], true) && max($largeur, $hauteur) < $cote) {
                continue;
            }
            $echelle = min(1, $cote / max($largeur, $hauteur));
            $l = max(1, (int) round($largeur * $echelle));
            $h = max(1, (int) round($hauteur * $echelle));
            $petite = $echelle < 1 ? imagescale($image, $l, $h, IMG_BICUBIC) : $image;
            $chemin = "contenus/{$contenu->ulid}/{$usage}.webp";
            ob_start();
            imagewebp($petite, null, $qualite);
            Medias::public()->put($chemin, (string) ob_get_clean(), ['ContentType' => 'image/webp', 'CacheControl' => Medias::CACHE]);
            if ($petite !== $image) {
                imagedestroy($petite);
            }
            $contenu->variantes()->updateOrCreate(['usage' => $usage], ['chemin' => $chemin, 'largeur' => $l, 'hauteur' => $h]);
        }
        imagedestroy($image);
    }

    /**
     * La vidéo d'un reel : la 720p pour tous (données mobiles comprises) et la 1080p, plus nette,
     * pour le Wi-Fi. Un seul décodage pour les deux ; la 1080p n'est gardée que si la source
     * est plus grande que la 720p.
     */
    public function video(Contenu $contenu, string $source): void
    {
        $chemin = "contenus/{$contenu->ulid}/video.mp4";
        // ffmpeg écrit sur le disque du serveur ; le fichier fini part ensuite vers le public (R2).
        $sortie = Medias::travail()->path("contenus/{$contenu->ulid}/video-servie.mp4");
        $sortieHd = Medias::travail()->path("contenus/{$contenu->ulid}/video-servie-1080.mp4");
        if (! is_dir(dirname($sortie))) {
            mkdir(dirname($sortie), 0700, true);
        }
        $ffmpeg = config('services.ffmpeg.chemin');
        $fait = false;
        $hd = false;
        if ($ffmpeg) {
            // Le grand côté ramené à $long (1280 : la 720p ; 1920 : la 1080p), debout comme couchée : une
            // vidéo couchée gardait sinon 720 px de large (720 × 405). Jamais agrandie (min).
            $echelle = fn (int $long, string $sortieDe) => "[{$sortieDe}]scale=w='if(gt(iw,ih),min({$long},iw),-2)':h='if(gt(iw,ih),-2,min({$long},ih))'";
            $son = ['-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', '-map_metadata', '-1'];
            // La musique choisie (comme sur TikTok) : mêlée au son d'origine, à leurs volumes.
            [$entrees, $filtreSon, $pistes] = $this->musique($contenu, $ffmpeg, $source);
            $r = Process::timeout(420)->run([
                $ffmpeg, '-y', '-threads', '2', '-i', $source, ...$entrees, '-t', '61',
                '-filter_complex', '[0:v]split=2[a][b];'.$echelle(1280, 'a').'[v720];'.$echelle(1920, 'b').'[v1080]'.$filtreSon,
                '-map', '[v720]', '-map', $pistes[0], '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-preset', 'medium', '-crf', '23', '-maxrate', '2500k', '-bufsize', '5000k', ...$son, $sortie,
                '-map', '[v1080]', '-map', $pistes[1], '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-preset', 'medium', '-crf', '21', '-maxrate', '5000k', '-bufsize', '10000k', ...$son, $sortieHd,
            ]);
            if (isset($entrees[3])) {
                @unlink($entrees[3]);
            }
            $fait = $r->successful() && is_file($sortie) && filesize($sortie) > 0;
            // Le plus petit côté de la source, lu dans ce que ffmpeg écrit (« 1080x1920 »).
            $court = preg_match('/Stream #0:\d+.*?Video:.*?(\d{2,5})x(\d{2,5})/', $r->errorOutput(), $m) === 1 ? min((int) $m[1], (int) $m[2]) : 0;
            $hd = $fait && $court > 720 && is_file($sortieHd) && filesize($sortieHd) > 0;
        }
        if (! $fait && $ffmpeg) {
            // La vidéo d'origine n'est jamais servie telle quelle : l'analyse réessaiera, puis l'équipe.
            @unlink($sortie);
            throw new RuntimeException('La vidéo n’a pas pu être ré-encodée.');
        }
        if (! $fait) {
            // Sans ffmpeg (développement, tests) : la vidéo telle quelle.
            copy($source, $sortie);
        }
        $flux = fopen($sortie, 'rb');
        Medias::public()->writeStream($chemin, $flux, ['ContentType' => 'video/mp4', 'CacheControl' => Medias::CACHE]);
        if (is_resource($flux)) {
            fclose($flux);
        }
        if ($fait) {
            // L'aperçu des grilles, tiré de la 720p ; raté, les grilles lisent la 720p.
            try {
                $this->apercuVideo($contenu, $sortie);
            } catch (Throwable $e) {
                report($e);
            }
        }
        @unlink($sortie);
        $contenu->variantes()->updateOrCreate(['usage' => UsageVariante::Video->value], ['chemin' => $chemin, 'largeur' => null, 'hauteur' => null]);

        if ($hd) {
            $cheminHd = "contenus/{$contenu->ulid}/video-1080.mp4";
            $flux = fopen($sortieHd, 'rb');
            Medias::public()->writeStream($cheminHd, $flux, ['ContentType' => 'video/mp4', 'CacheControl' => Medias::CACHE]);
            if (is_resource($flux)) {
                fclose($flux);
            }
            $contenu->variantes()->updateOrCreate(['usage' => UsageVariante::VideoHd->value], ['chemin' => $cheminHd, 'largeur' => null, 'hauteur' => null]);
        }
        @unlink($sortieHd);
    }

    /**
     * L'aperçu d'un reel, lu sans le son dans les grilles et les piles (comme Pinterest) : 640 px au
     * plus grand côté, sans son, autour de 0,6 Mb/s. Quatre se lisent à la fois sur un réseau
     * mobile, là où la 720p (jusqu'à 2,5 Mb/s chacune) les faisait attendre. Sans ffmpeg, ou raté :
     * pas d'aperçu, les grilles lisent la 720p.
     */
    public function apercuVideo(Contenu $contenu, string $source): bool
    {
        $ffmpeg = config('services.ffmpeg.chemin');
        if (! $ffmpeg) {
            return false;
        }
        $sortie = Medias::travail()->path("contenus/{$contenu->ulid}/video-servie-640.mp4");
        if (! is_dir(dirname($sortie))) {
            mkdir(dirname($sortie), 0700, true);
        }
        $r = Process::timeout(300)->run([
            $ffmpeg, '-y', '-threads', '2', '-i', $source, '-t', '61', '-an',
            '-vf', "scale=w='if(gt(iw,ih),min(640,iw),-2)':h='if(gt(iw,ih),-2,min(640,ih))'",
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-profile:v', 'main', '-preset', 'medium', '-crf', '30', '-maxrate', '700k', '-bufsize', '1400k',
            '-movflags', '+faststart', '-map_metadata', '-1', $sortie,
        ]);
        if (! $r->successful() || ! is_file($sortie) || filesize($sortie) === 0) {
            @unlink($sortie);

            return false;
        }
        $chemin = "contenus/{$contenu->ulid}/video-640.mp4";
        $flux = fopen($sortie, 'rb');
        Medias::public()->writeStream($chemin, $flux, ['ContentType' => 'video/mp4', 'CacheControl' => Medias::CACHE]);
        if (is_resource($flux)) {
            fclose($flux);
        }
        @unlink($sortie);
        $contenu->variantes()->updateOrCreate(['usage' => UsageVariante::VideoApercu->value], ['chemin' => $chemin, 'largeur' => null, 'hauteur' => null]);

        return true;
    }

    /**
     * La musique d'un reel, pour ffmpeg : l'entrée (le son, depuis son extrait), le filtre qui la
     * mêle au son d'origine et les deux pistes à garder. Sans musique : le son d'origine tel quel.
     *
     * @return array{0: list<string>, 1: string, 2: array{0: string, 1: string}}
     */
    private function musique(Contenu $contenu, string $ffmpeg, string $source): array
    {
        $musique = $contenu->son_id ? $contenu->musique : null;
        if ($musique === null || ! Medias::public()->exists($musique->chemin)) {
            return [[], '', ['0:a?', '0:a?']];
        }
        $fichier = Medias::travail()->path("contenus/{$contenu->ulid}/musique.m4a");
        $flux = Medias::public()->readStream($musique->chemin);
        file_put_contents($fichier, $flux);
        if (is_resource($flux)) {
            fclose($flux);
        }
        // La durée de la vidéo et si elle a un son, lus dans ce que ffmpeg dit d'elle.
        $infos = Process::timeout(60)->run([$ffmpeg, '-hide_banner', '-i', $source])->errorOutput();
        $duree = preg_match('/Duration: (\d+):(\d+):(\d+(?:\.\d+)?)/', $infos, $m) === 1 ? min(61.0, ((int) $m[1] * 60 + (int) $m[2]) * 60 + (float) $m[3]) : (float) ($contenu->duree ?: 60);
        $aDuSon = preg_match('/Stream #0:\d+.*?Audio:/', $infos) === 1;
        $vm = number_format(($contenu->son_volume ?? 100) / 100, 2, '.', '');
        $vo = number_format(($contenu->origine_volume ?? 100) / 100, 2, '.', '');
        $fin = number_format(max(0, $duree - 0.8), 2, '.', '');
        $d = number_format($duree, 2, '.', '');
        // La musique s'éteint doucement à la fin ; le limiteur évite que les deux ensemble saturent.
        $mix = $aDuSon && $vo !== '0.00'
            ? ";[0:a]aformat=channel_layouts=stereo,volume={$vo}[ao];[1:a]aformat=channel_layouts=stereo,volume={$vm}[am];[ao][am]amix=inputs=2:duration=longest:dropout_transition=0:normalize=0"
            : ";[1:a]aformat=channel_layouts=stereo,volume={$vm}";
        $filtre = $mix.",atrim=0:{$d},afade=t=out:st={$fin}:d=0.8,alimiter=limit=0.95,asplit=2[s720][s1080]";

        return [['-ss', number_format(($contenu->son_debut_ms ?? 0) / 1000, 3, '.', ''), '-i', $fichier], $filtre, ['[s720]', '[s1080]']];
    }

    private function ouvrir(string $source): \GdImage
    {
        Dimensions::verifier($source);
        $image = @imagecreatefromstring((string) file_get_contents($source));
        if (! $image) {
            throw new RuntimeException('Image illisible.');
        }
        // L'original d'un téléphone est souvent couché, avec l'ordre de le redresser dans l'EXIF.
        $orientation = function_exists('exif_read_data') ? (int) (@exif_read_data($source)['Orientation'] ?? 1) : 1;
        $image = match ($orientation) {
            3 => imagerotate($image, 180, 0),
            6 => imagerotate($image, -90, 0),
            8 => imagerotate($image, 90, 0),
            default => $image,
        };
        if (! imageistruecolor($image)) {
            imagepalettetotruecolor($image);
        }

        return $image;
    }
}
