<?php

namespace App\Services\Lieux;

use App\Models\Lieu;
use App\Models\Pays;
use App\Models\Ville;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Throwable;

/**
 * Chercher un lieu par son nom avec Google (Places API, New) : « uac ifri » donne l'Institut
 * de Formation et de Recherche en Informatique, avec sa position exacte. La clé (GOOGLE_PLACES)
 * reste sur le serveur ; sans elle, la recherche ne trouve que les lieux de Discover.
 */
class PlacesGoogle
{
    /** Un lieu de Discover à moins de 150 m du lieu de Google : c'est le même. */
    private const MEME_LIEU_KM = 0.15;

    public function __construct(private RapprocheurLieu $rapprocheur) {}

    public function configure(): bool
    {
        return (string) config('services.google_places.cle') !== '';
    }

    /**
     * Les suggestions de Google pour ce texte, près d'une position si elle est donnée.
     *
     * @return list<array{id: string, nom: string, adresse: string}>
     */
    public function suggestions(string $texte, ?float $lat = null, ?float $lon = null): array
    {
        if (! $this->configure()) {
            return [];
        }
        $cle = 'places:'.md5(json_encode([Lieu::normaliser($texte), $lat === null ? null : round($lat, 1), $lon === null ? null : round($lon, 1)]));

        $gardees = Cache::get($cle);
        if (is_array($gardees)) {
            return $gardees;
        }
        // Seule une réponse de Google se garde (un jour) : une panne passagère ne doit pas
        // laisser ce texte sans suggestions jusqu'au lendemain.
        $suggestions = (function () use ($texte, $lat, $lon) {
            try {
                $r = Http::withHeaders(['X-Goog-Api-Key' => config('services.google_places.cle')])
                    ->timeout(8)
                    ->post('https://places.googleapis.com/v1/places:autocomplete', array_filter([
                        'input' => $texte,
                        'languageCode' => 'fr',
                        'locationBias' => $lat === null || $lon === null ? null : [
                            'circle' => ['center' => ['latitude' => $lat, 'longitude' => $lon], 'radius' => 50000.0],
                        ],
                    ]));
                if (! $r->successful()) {
                    return null;
                }

                return collect($r->json('suggestions') ?? [])
                    ->pluck('placePrediction')->filter()
                    ->map(fn (array $p) => [
                        'id' => (string) $p['placeId'],
                        'nom' => (string) ($p['structuredFormat']['mainText']['text'] ?? $p['text']['text'] ?? ''),
                        'adresse' => (string) ($p['structuredFormat']['secondaryText']['text'] ?? ''),
                    ])
                    ->filter(fn (array $p) => $p['nom'] !== '')
                    ->take(6)->values()->all();
            } catch (Throwable) {
                return null;
            }
        })();
        if ($suggestions === null) {
            return [];
        }
        Cache::put($cle, $suggestions, now()->addDay());

        return $suggestions;
    }

    /** Le nom et la position d'un lieu de Google, sans rien créer (aller le voir sur la carte). */
    public function position(string $id): ?array
    {
        $details = $this->details($id);
        $lat = $details['location']['latitude'] ?? null;
        $lon = $details['location']['longitude'] ?? null;
        $nom = trim((string) ($details['displayName']['text'] ?? ''));

        return $lat === null || $lon === null ? null : ['nom' => $nom, 'latitude' => (float) $lat, 'longitude' => (float) $lon];
    }

    /** Les détails d'un lieu de Google, gardés une semaine (un échec ne se garde pas). */
    private function details(string $id): ?array
    {
        if (! $this->configure()) {
            return null;
        }

        return Cache::remember('places:details:'.$id, now()->addWeek(), function () use ($id) {
            try {
                $r = Http::withHeaders([
                    'X-Goog-Api-Key' => config('services.google_places.cle'),
                    'X-Goog-FieldMask' => 'id,displayName,location,addressComponents,types',
                ])->timeout(8)->get('https://places.googleapis.com/v1/places/'.rawurlencode($id), ['languageCode' => 'fr']);

                return $r->successful() ? $r->json() : null;
            } catch (Throwable) {
                return null;
            }
        });
    }

    /** Le lieu de Discover pour ce lieu de Google : celui qui est déjà là, sinon créé. */
    public function lieu(string $id): ?Lieu
    {
        $details = $this->details($id);
        $lat = $details['location']['latitude'] ?? null;
        $lon = $details['location']['longitude'] ?? null;
        $nom = trim((string) ($details['displayName']['text'] ?? ''));
        if ($lat === null || $lon === null || $nom === '') {
            return null;
        }
        if ($r = $this->rapprocheur->proche((float) $lat, (float) $lon, self::MEME_LIEU_KM)) {
            return $r->lieu;
        }
        $partie = fn (string $type, string $champ = 'longText') => collect($details['addressComponents'] ?? [])
            ->first(fn ($c) => in_array($type, $c['types'] ?? [], true))[$champ] ?? null;

        return self::creer($nom, (float) $lat, (float) $lon, $partie('locality') ?? $partie('administrative_area_level_2'), $partie('administrative_area_level_1'), $partie('country'), $partie('country', 'shortText'), TypeDeLieu::deviner($nom, $details['types'] ?? []));
    }

    /** Un nouveau lieu de Discover, à sa position ; sa ville et son pays s'ils sont connus. Sans type donné, il est deviné par le nom. */
    public static function creer(string $nom, ?float $lat, ?float $lon, ?string $ville, ?string $region, ?string $pays, ?string $paysCode, ?string $type = null): Lieu
    {
        $idVille = null;
        if ($pays && $paysCode && strlen($paysCode) === 2) {
            $p = Pays::firstOrCreate(['code' => Str::upper($paysCode)], ['nom' => $pays]);
            $idVille = Ville::firstOrCreate(['pays_id' => $p->id, 'nom' => $ville ?: $nom], ['region' => $region])->id;
        }
        $slug = Str::slug($nom) ?: 'lieu';
        $base = $slug;
        for ($i = 2; Lieu::where('slug', $slug)->exists(); $i++) {
            $slug = "{$base}-{$i}";
        }

        return Lieu::create(['slug' => $slug, 'nom' => Str::limit($nom, 157), 'ville_id' => $idVille, 'type' => $type ?? TypeDeLieu::deviner($nom), 'latitude' => $lat, 'longitude' => $lon]);
    }
}
