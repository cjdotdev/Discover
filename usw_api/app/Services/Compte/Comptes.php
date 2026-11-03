<?php

namespace App\Services\Compte;

use App\Models\Utilisateur;
use App\Support\Dimensions;
use App\Support\Medias;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use RuntimeException;

/** Ce qui touche aux comptes, hors HTTP : jetons, noms d'utilisateur, photo de profil. */
class Comptes
{
    /** Un jeton Sanctum pour ce téléphone ; il expire après 30 jours sans usage. */
    public function jeton(Utilisateur $u, ?string $appareil = null): string
    {
        return $u->createToken(Str::limit($appareil ?: 'application', 60, ''))->plainTextToken;
    }

    /** Un nom d'utilisateur libre à partir d'un nom : « akouavi.kossou », sinon « akouavi.kossou2 »… */
    public function nomLibre(string $depart, ?int $sauf = null): string
    {
        $base = Str::of(Str::before($depart, '@'))->ascii()->lower()->replaceMatches('/[^a-z0-9._]/', '')->trim('.')->limit(24, '')->toString();
        $base = strlen($base) >= 3 ? $base : 'membre';
        $nom = $base;
        for ($i = 2; Utilisateur::where('nom_utilisateur', $nom)->when($sauf, fn ($q) => $q->whereKeyNot($sauf))->exists(); $i++) {
            $nom = $base.$i;
        }

        return $nom;
    }

    /**
     * La photo de profil, ré-encodée en WebP 512 px (ce qui retire tout contenu caché et les
     * métadonnées), sur le disque public. L'ancienne est supprimée.
     */
    public function changerAvatar(Utilisateur $u, UploadedFile $fichier): string
    {
        Dimensions::verifier($fichier->getRealPath());
        $image = @imagecreatefromstring((string) file_get_contents($fichier->getRealPath()));
        if ($image === false) {
            throw new RuntimeException('Image illisible.');
        }
        $l = imagesx($image);
        $h = imagesy($image);
        $cote = min($l, $h);
        // Un carré au centre, comme l'avatar rond qui l'affiche.
        $carre = imagecreatetruecolor(512, 512);
        imagecopyresampled($carre, $image, 0, 0, intdiv($l - $cote, 2), intdiv($h - $cote, 2), 512, 512, $cote, $cote);
        ob_start();
        imagewebp($carre, null, 82);
        $octets = (string) ob_get_clean();
        imagedestroy($image);
        imagedestroy($carre);

        $chemin = "avatars/{$u->ulid}-".now()->timestamp.'.webp';
        Medias::public()->put($chemin, $octets, ['ContentType' => 'image/webp', 'CacheControl' => Medias::CACHE]);
        $ancien = $u->avatar;
        $u->update(['avatar' => $chemin]);
        self::effacerAvatar($ancien);

        return $chemin;
    }

    /** Retirer la photo de profil : les initiales la remplacent partout. */
    public function retirerAvatar(Utilisateur $u): void
    {
        $ancien = $u->avatar;
        $u->update(['avatar' => null]);
        self::effacerAvatar($ancien);
    }

    /** Une photo de profil et son aperçu JPEG (celui des liens partagés). */
    public static function effacerAvatar(?string $chemin): void
    {
        if ($chemin) {
            Medias::public()->delete([$chemin, preg_replace('/\.webp$/', '.jpg', $chemin)]);
        }
    }
}
