<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;

/**
 * Les langues à télécharger dans l'application (le français et l'anglais y sont déjà). Un
 * paquet par langue, dans resources/langues/{code}.json : le texte français est la clé, la
 * traduction la valeur. Les langues africaines viennent d'abord, par ordre alphabétique.
 */
class LangueController extends Controller
{
    /** GET langues : [{code, nom, nom_fr, africaine, a_relire, version, taille_ko}] */
    public function index(): JsonResponse
    {
        $liste = Cache::remember('langues:liste:'.self::empreinte(), now()->addDay(), function () {
            $langues = [];
            foreach (glob(self::dossier().'/*.json') ?: [] as $f) {
                $j = json_decode((string) file_get_contents($f), true);
                if (! is_array($j) || ! isset($j['code'], $j['textes']) || in_array($j['code'], ['fr', 'en'], true)) {
                    continue;
                }
                $langues[] = [
                    'code' => $j['code'],
                    'nom' => $j['nom'] ?? $j['code'],
                    'nom_fr' => $j['nom_fr'] ?? null,
                    'africaine' => (bool) ($j['africaine'] ?? false),
                    'a_relire' => (bool) ($j['a_relire'] ?? false),
                    'version' => (int) ($j['version'] ?? 1),
                    'taille_ko' => (int) ceil(filesize($f) / 1024),
                ];
            }
            usort($langues, fn ($a, $b) => [! $a['africaine'], self::cle($a['nom'])] <=> [! $b['africaine'], self::cle($b['nom'])]);

            return $langues;
        });

        return response()->json(['data' => $liste])->header('Cache-Control', 'public, max-age=3600');
    }

    /** GET langues/{code} : le paquet entier. */
    public function paquet(Request $requete, string $code): Response
    {
        abort_unless(preg_match('/^[a-z]{2,3}$/', $code) === 1, 404);
        $f = self::dossier()."/{$code}.json";
        abort_unless(is_file($f), 404);
        $etiquette = '"'.md5_file($f).'"';
        if ($requete->header('If-None-Match') === $etiquette) {
            return response('', 304)->header('ETag', $etiquette);
        }

        return response((string) file_get_contents($f), 200, [
            'Content-Type' => 'application/json; charset=utf-8',
            'Cache-Control' => 'public, max-age=3600',
            'ETag' => $etiquette,
        ]);
    }

    private static function dossier(): string
    {
        return resource_path('langues');
    }

    /** Change quand un paquet change : la liste en cache se refait. */
    private static function empreinte(): string
    {
        return md5(implode('|', array_map(fn ($f) => $f.filemtime($f), glob(self::dossier().'/*.json') ?: [])));
    }

    private static function cle(string $nom): string
    {
        return mb_strtolower(transliterator_transliterate('Any-Latin; Latin-ASCII', $nom) ?: $nom);
    }
}
