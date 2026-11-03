<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Localite;
use Collator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Locale;

/**
 * Le choix du pays et de la ville du profil, sans la position : tous les pays, dans la langue
 * de l'application et par ordre alphabétique, puis les villes du pays choisi.
 */
class GeoController extends Controller
{
    /** Des codes que intl connaît mais qui ne sont pas des pays d'aujourd'hui. */
    private const ECARTES = ['AC', 'AN', 'BU', 'CP', 'CS', 'DD', 'DG', 'DY', 'EA', 'EU', 'EZ', 'FX', 'HV', 'IC', 'NH', 'QO', 'RH', 'SU', 'TA', 'TP', 'UK', 'UN', 'VD', 'XA', 'XB', 'YD', 'YU', 'ZR', 'ZZ'];

    /** GET geo/pays?langue=fr : [{code, nom}], par ordre alphabétique dans cette langue. */
    public function pays(Request $requete): JsonResponse
    {
        $langue = $this->langue($requete);
        $liste = Cache::remember("geo:pays:{$langue}", now()->addWeek(), function () use ($langue) {
            $pays = [];
            foreach (range('A', 'Z') as $a) {
                foreach (range('A', 'Z') as $b) {
                    $code = $a.$b;
                    $nom = Locale::getDisplayRegion("-{$code}", $langue);
                    if ($nom !== $code && $nom !== '' && ! in_array($code, self::ECARTES, true)) {
                        $pays[] = ['code' => $code, 'nom' => $nom];
                    }
                }
            }
            $tri = new Collator($langue);
            usort($pays, fn ($x, $y) => $tri->compare($x['nom'], $y['nom']));

            return $pays;
        });

        return response()->json(['data' => $liste])->header('Cache-Control', 'public, max-age=86400');
    }

    /**
     * GET geo/pays/{code}/villes?q= : sans texte, les 300 plus peuplées par ordre alphabétique ;
     * avec un texte, les 50 qui commencent par lui (ou un de leurs mots), les plus peuplées d'abord.
     */
    public function villes(Request $requete, string $code): JsonResponse
    {
        $code = strtoupper($code);
        abort_unless(preg_match('/^[A-Z]{2}$/', $code) === 1, 404);
        $q = Localite::normaliser(mb_substr((string) $requete->query('q', ''), 0, 60));
        $colonnes = ['nom', 'region', 'latitude', 'longitude'];

        if ($q === '') {
            $villes = Cache::remember("geo:villes:{$code}:{$this->langue($requete)}", now()->addDay(), function () use ($code, $colonnes, $requete) {
                $liste = Localite::where('pays', $code)->orderByDesc('population')->limit(300)->get($colonnes)->toArray();
                $tri = new Collator($this->langue($requete));
                usort($liste, fn ($x, $y) => $tri->compare($x['nom'], $y['nom']));

                return $liste;
            });
        } else {
            $villes = Localite::where('pays', $code)
                ->where(fn ($w) => $w->where('recherche', 'like', "{$q}%")->orWhere('recherche', 'like', "% {$q}%"))
                ->orderByDesc('population')->limit(50)->get($colonnes)->toArray();
        }

        return response()->json(['data' => $villes]);
    }

    private function langue(Request $requete): string
    {
        $l = strtolower((string) ($requete->query('langue') ?: $requete->getPreferredLanguage() ?: 'fr'));
        $l = substr(str_replace('-', '_', $l), 0, 3);
        $l = rtrim($l, '_');

        return preg_match('/^[a-z]{2,3}$/', $l) === 1 ? $l : 'fr';
    }
}
