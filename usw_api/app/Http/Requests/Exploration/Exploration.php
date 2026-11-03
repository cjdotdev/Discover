<?php

namespace App\Http\Requests\Exploration;

use App\Models\Lieu;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Pagination\Cursor;
use Illuminate\Support\Facades\Cache;

/**
 * Lot 4 : les requêtes d'exploration, ouvertes aux visiteurs. Les types de lieux arrivent
 * séparés par des virgules (`types=Plages,Cascades`), comme les filtres de l'application.
 */
abstract class Exploration extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return list<string> */
    public function types(): array
    {
        $brut = (string) ($this->validated('types') ?? '');
        $demandes = array_unique(array_filter(array_map('trim', explode(',', $brut)), fn ($t) => $t !== ''));
        if ($demandes === []) {
            return [];
        }
        // Seulement les types qui existent, triés : une clé de cache par vraie combinaison.
        $connus = Cache::remember('lieux:types', 600, fn () => Lieu::query()->distinct()->pluck('type')->filter()->values()->all());
        $types = array_values(array_intersect($connus, $demandes));
        sort($types);

        return $types;
    }

    protected static function curseur(): array
    {
        // Un curseur de page (encodé par Laravel) ou un rang (« Pour toi ») : rien d'autre.
        return ['nullable', 'string', 'max:500', function (string $attribut, mixed $valeur, \Closure $echec) {
            if (! ctype_digit((string) $valeur) && Cursor::fromEncoded((string) $valeur) === null) {
                $echec('Cette page n’existe pas.');
            }
        }];
    }

    protected static function typesListe(): array
    {
        return ['nullable', 'string', 'max:400'];
    }

    protected static function position(bool $obligatoire): array
    {
        $r = $obligatoire ? 'required' : 'nullable';

        return [
            'latitude' => [$r, 'numeric', 'between:-90,90'],
            'longitude' => [$obligatoire ? 'required' : 'required_with:latitude', 'numeric', 'between:-180,180'],
            'rayon' => ['nullable', 'numeric', 'min:1', 'max:500'],
        ];
    }
}
