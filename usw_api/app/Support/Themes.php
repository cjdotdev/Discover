<?php

namespace App\Support;

use App\Models\Lieu;

/**
 * Ce qu'on voit sur une photo : les étiquettes que le téléphone lit dans l'image (Google ML Kit,
 * en anglais : « Forest », « Beach », « Food »…), regroupées en thèmes (les goûts choisis à
 * l'inscription) et reliées aux mots qu'on tape dans la recherche (« arbre » trouve les photos
 * où il y a des arbres, même si personne ne l'a écrit).
 */
class Themes
{
    /** La confiance minimale d'une étiquette pour qu'une photo en parle. */
    public const CONFIANCE = 0.6;

    /** Les thèmes proposés à l'inscription, dans leur ordre, et les étiquettes de chacun. */
    public const THEMES = [
        'nature' => ['forest', 'plant', 'flora', 'branch', 'twig', 'jungle', 'garden', 'park', 'field', 'prairie', 'soil', 'swamp', 'trunk', 'petal', 'flower'],
        'paysages' => ['mountain', 'cliff', 'canyon', 'glacier', 'volcano', 'desert', 'dune', 'sky', 'field', 'prairie', 'lake', 'river', 'waterfall', 'rainbow', 'fog', 'aurora', 'cave'],
        'mer' => ['beach', 'sand', 'reef', 'underwater', 'surfing', 'surfboard', 'boat', 'sailboat', 'pier', 'lighthouse', 'scuba diving', 'snorkeling', 'shipwreck', 'windsurfing', 'kayak', 'canoe', 'speedboat', 'swimming', 'swimwear', 'shell'],
        'nourriture' => ['food', 'cuisine', 'meal', 'fruit', 'vegetable', 'bread', 'cake', 'pizza', 'sushi', 'fast food', 'hot dog', 'cheeseburger', 'juice', 'coffee', 'cappuccino', 'cookie', 'pie', 'supper', 'lunch', 'couscous', 'pho', 'pasteles', 'gelato', 'bento', 'wine', 'cola', 'tableware', 'steaming', 'eating'],
        'architecture' => ['building', 'skyscraper', 'tower', 'skyline', 'bridge', 'church', 'cathedral', 'mosque', 'temple', 'palace', 'castle', 'monument', 'ruins', 'roof', 'wall', 'brick', 'stairs', 'infrastructure', 'dam', 'construction', 'museum', 'stadium', 'tile'],
        'animaux' => ['bird', 'cat', 'dog', 'horse', 'cattle', 'bull', 'bear', 'duck', 'turtle', 'crocodile', 'penguin', 'butterfly', 'insect', 'seal', 'herd', 'pet', 'waterfowl', 'safari', 'fur', 'dalmatian', 'gerbil', 'aquarium'],
        'fleurs' => ['flower', 'petal', 'flora', 'flowerpot', 'garden', 'wreath', 'centrepiece'],
        'ville' => ['skyline', 'road', 'asphalt', 'car', 'bus', 'vehicle', 'van', 'motorcycle', 'bicycle', 'train', 'neon', 'bar', 'community', 'crowd', 'rickshaw', 'building', 'skyscraper'],
        'couchers' => ['sunset', 'sky', 'moon', 'star', 'aurora', 'rainbow'],
        'cascades' => ['waterfall', 'river', 'lake', 'dam', 'rafting'],
        'culture' => ['monument', 'statue', 'museum', 'ruins', 'temple', 'church', 'mosque', 'sari', 'jewellery', 'necklace', 'bracelet', 'bangle', 'textile', 'carnival', 'dance', 'musical instrument', 'pattern', 'porcelain', 'palace'],
        'fetes' => ['party', 'concert', 'event', 'dance', 'carnival', 'fireworks', 'sparkler', 'crowd', 'musician', 'singer', 'deejay', 'marriage', 'bride', 'groom', 'christmas', 'balloon', 'nightclub', 'fun', 'pop music', 'musical'],
    ];

    /**
     * Les mots de la recherche (français et anglais, sans accents ni pluriel) et ce qu'ils
     * trouvent sur les photos. Le nom d'un thème trouve tout le thème.
     */
    private const MOTS = [
        'arbre' => ['forest', 'plant', 'flora', 'branch', 'twig', 'jungle', 'trunk', 'park', 'garden'],
        'tree' => ['forest', 'plant', 'flora', 'branch', 'twig', 'jungle', 'trunk', 'park', 'garden'],
        'foret' => ['forest', 'jungle'],
        'bois' => ['forest', 'twig', 'branch'],
        'plante' => ['plant', 'flora', 'flowerpot'],
        'vert' => ['forest', 'plant', 'flora', 'field', 'prairie', 'garden'],
        'verdure' => ['forest', 'plant', 'flora', 'field', 'prairie', 'garden'],
        'fleur' => ['flower', 'petal', 'flora', 'flowerpot'],
        'jardin' => ['garden', 'flower', 'plant'],
        'parc' => ['park', 'garden', 'playground'],
        'champ' => ['field', 'prairie', 'farm'],
        'ferme' => ['farm', 'barn', 'ranch', 'cattle'],
        'plage' => ['beach', 'sand'],
        'sable' => ['sand', 'beach', 'dune'],
        'ocean' => ['beach', 'reef', 'underwater', 'surfing', 'boat'],
        'vague' => ['surfing', 'beach'],
        'bateau' => ['boat', 'sailboat', 'speedboat', 'canoe', 'kayak', 'skiff', 'brig'],
        'pirogue' => ['canoe', 'boat', 'kayak'],
        'peche' => ['fishing', 'boat'],
        'lac' => ['lake'],
        'lagune' => ['lake', 'swamp'],
        'riviere' => ['river'],
        'fleuve' => ['river'],
        'eau' => ['lake', 'river', 'waterfall', 'beach', 'underwater', 'pool'],
        'cascade' => ['waterfall'],
        'chute' => ['waterfall'],
        'montagne' => ['mountain', 'cliff', 'glacier', 'volcano', 'canyon'],
        'colline' => ['mountain', 'field', 'prairie'],
        'rocher' => ['rock', 'cliff'],
        'grotte' => ['cave', 'caving'],
        'desert' => ['desert', 'dune'],
        'ciel' => ['sky'],
        'nuage' => ['sky', 'fog'],
        'soleil' => ['sunset', 'sky'],
        'coucher' => ['sunset'],
        'lever' => ['sunset'],
        'nuit' => ['moon', 'star', 'neon', 'nightclub'],
        'lune' => ['moon'],
        'etoile' => ['star', 'nebula'],
        'nourriture' => self::THEMES['nourriture'],
        'manger' => self::THEMES['nourriture'],
        'plat' => ['food', 'cuisine', 'meal', 'tableware'],
        'repas' => ['food', 'cuisine', 'meal', 'supper', 'lunch'],
        'cuisine' => ['food', 'cuisine', 'meal', 'kitchen'],
        'restaurant' => ['food', 'cuisine', 'meal', 'tableware', 'menu'],
        'fruit' => ['fruit'],
        'legume' => ['vegetable'],
        'pain' => ['bread'],
        'gateau' => ['cake', 'pie', 'cookie', 'icing'],
        'cafe' => ['coffee', 'cappuccino'],
        'boisson' => ['juice', 'cola', 'wine', 'coffee', 'alcohol'],
        'vin' => ['wine'],
        'immeuble' => ['building', 'skyscraper', 'tower'],
        'batiment' => ['building', 'skyscraper', 'tower', 'construction'],
        'maison' => ['building', 'roof', 'room'],
        'gratte' => ['skyscraper'],
        'tour' => ['tower', 'skyscraper'],
        'pont' => ['bridge'],
        'eglise' => ['church', 'cathedral'],
        'cathedrale' => ['cathedral', 'church'],
        'mosquee' => ['mosque'],
        'temple' => ['temple'],
        'palais' => ['palace'],
        'chateau' => ['castle', 'palace'],
        'musee' => ['museum'],
        'statue' => ['statue', 'monument'],
        'monument' => ['monument', 'statue'],
        'ruine' => ['ruins'],
        'patrimoine' => ['monument', 'statue', 'museum', 'ruins', 'palace', 'temple'],
        'ville' => self::THEMES['ville'],
        'rue' => ['road', 'asphalt'],
        'route' => ['road', 'asphalt'],
        'voiture' => ['car', 'vehicle'],
        'moto' => ['motorcycle'],
        'velo' => ['bicycle', 'cycling'],
        'avion' => ['airplane', 'aircraft', 'airliner', 'aviation'],
        'animal' => self::THEMES['animaux'],
        'chien' => ['dog', 'dalmatian', 'pet'],
        'chat' => ['cat', 'pet'],
        'oiseau' => ['bird', 'waterfowl', 'duck', 'penguin'],
        'cheval' => ['horse'],
        'vache' => ['cattle', 'bull', 'herd'],
        'boeuf' => ['cattle', 'bull'],
        'ours' => ['bear'],
        'canard' => ['duck', 'waterfowl'],
        'tortue' => ['turtle'],
        'crocodile' => ['crocodile'],
        'papillon' => ['butterfly'],
        'insecte' => ['insect', 'butterfly'],
        'poisson' => ['aquarium', 'underwater', 'reef', 'fishing', 'pomacentridae'],
        'fete' => self::THEMES['fetes'],
        'concert' => ['concert', 'musician', 'singer', 'crowd'],
        'musique' => ['musical instrument', 'musician', 'concert', 'singer', 'pop music', 'deejay'],
        'danse' => ['dance', 'ballroom'],
        'mariage' => ['marriage', 'bride', 'groom', 'gown', 'veil'],
        'feu' => ['fire', 'bonfire', 'fireworks'],
        'artifice' => ['fireworks', 'sparkler'],
        'bijou' => ['jewellery', 'necklace', 'bracelet', 'bangle', 'ring'],
        'perle' => ['jewellery', 'necklace', 'bracelet', 'bangle'],
        'pagne' => ['textile', 'pattern'],
        'tissu' => ['textile', 'pattern'],
        'sport' => ['sports', 'soccer', 'stadium', 'running', 'cycling', 'race'],
        'football' => ['soccer', 'stadium', 'pitch'],
        'bebe' => ['baby'],
        'enfant' => ['baby', 'playground', 'school'],
    ];

    /** Les étiquettes qu'un mot de la recherche trouve (vide : le mot ne parle pas d'image). */
    public static function etiquettesPour(string $mot): array
    {
        $m = Lieu::normaliser($mot);
        if ($m === '') {
            return [];
        }
        foreach ([$m, preg_replace('/(s|x)$/', '', $m)] as $forme) {
            if (isset(self::MOTS[$forme])) {
                return self::MOTS[$forme];
            }
            if (isset(self::THEMES[$forme])) {
                return self::THEMES[$forme];
            }
        }
        // Le nom anglais d'une étiquette (« beach », « dog ») se trouve lui-même.
        foreach (self::THEMES as $etiquettes) {
            if (in_array($m, $etiquettes, true)) {
                return [$m];
            }
        }

        return [];
    }

    /** Les étiquettes des thèmes choisis (les goûts d'un membre). */
    public static function etiquettesDes(array $themes): array
    {
        $etiquettes = [];
        foreach ($themes as $t) {
            $etiquettes = [...$etiquettes, ...(self::THEMES[$t] ?? [])];
        }

        return array_values(array_unique($etiquettes));
    }
}
