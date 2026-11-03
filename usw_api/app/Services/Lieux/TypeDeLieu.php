<?php

namespace App\Services\Lieux;

use Illuminate\Support\Str;

/**
 * Le type d'un lieu, parmi ceux de l'application (« Plages », « Cascades »…) : deviné par son nom,
 * puis par les types que Google lui donne. Sinon « Autres ». Les recommandations et les filtres
 * de la recherche s'en servent.
 */
class TypeDeLieu
{
    public const AUTRES = 'Autres';

    /** Les mots du nom (sans accents ni majuscules) ; le premier type qui correspond l'emporte. */
    private const MOTS = [
        'Cascades' => ['cascade', 'cascades', 'chute', 'chutes', 'waterfall', 'falls'],
        'Lacs et lagunes' => ['lac', 'lagune', 'lagunes', 'lake', 'lagoon', 'etang'],
        'Plages' => ['plage', 'plages', 'beach'],
        'Forêts' => ['foret', 'forets', 'forest', 'bois sacre', 'foret sacree'],
        'Savane et parcs' => ['parc', 'park', 'reserve', 'savane', 'safari', 'zoo', 'jardin botanique'],
        'Collines' => ['colline', 'collines', 'mont', 'monts', 'montagne', 'massif', 'falaise', 'falaises', 'pic', 'hill', 'mountain'],
        'Patrimoine' => ['musee', 'museum', 'palais', 'temple', 'fort', 'basilique', 'cathedrale', 'eglise', 'mosquee', 'monument', 'memorial', 'statue', 'porte du non retour', 'route des esclaves', 'tata', 'site historique'],
        'Villes et rues' => ['rue', 'avenue', 'boulevard', 'marche', 'quartier', 'centre ville', 'place', 'carrefour'],
    ];

    /** Les types de Google (Places API, New) et le nôtre. */
    private const GOOGLE = [
        'beach' => 'Plages',
        'national_park' => 'Savane et parcs',
        'state_park' => 'Savane et parcs',
        'park' => 'Savane et parcs',
        'wildlife_park' => 'Savane et parcs',
        'wildlife_refuge' => 'Savane et parcs',
        'zoo' => 'Savane et parcs',
        'botanical_garden' => 'Savane et parcs',
        'museum' => 'Patrimoine',
        'historical_landmark' => 'Patrimoine',
        'historical_place' => 'Patrimoine',
        'monument' => 'Patrimoine',
        'cultural_landmark' => 'Patrimoine',
        'church' => 'Patrimoine',
        'mosque' => 'Patrimoine',
        'hindu_temple' => 'Patrimoine',
        'place_of_worship' => 'Patrimoine',
        'locality' => 'Villes et rues',
        'sublocality' => 'Villes et rues',
        'neighborhood' => 'Villes et rues',
        'route' => 'Villes et rues',
        'market' => 'Villes et rues',
        'plaza' => 'Villes et rues',
    ];

    /** @param  list<string>  $typesGoogle */
    public static function deviner(string $nom, array $typesGoogle = []): string
    {
        $texte = ' '.trim((string) preg_replace('/[^a-z0-9]+/', ' ', Str::lower(Str::ascii($nom)))).' ';
        foreach (self::MOTS as $type => $mots) {
            foreach ($mots as $m) {
                if (str_contains($texte, " {$m} ")) {
                    return $type;
                }
            }
        }
        foreach ($typesGoogle as $t) {
            if (isset(self::GOOGLE[$t])) {
                return self::GOOGLE[$t];
            }
        }

        return self::AUTRES;
    }
}
