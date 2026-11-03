<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

/** Un lieu (E33) : une plage, une cascade, une rue. Il se montre par son slug. */
#[Fillable(['slug', 'nom', 'ville_id', 'type', 'latitude', 'longitude'])]
class Lieu extends Model
{
    use HasFactory, HasUlids;

    protected $table = 'lieux';

    /** La pile des photos sans lieu (ou avec un nom seul) : un lieu sans position, hors de la carte. */
    public const SANS_LIEU = 'sans-lieu';

    public static function sansLieu(): self
    {
        return self::firstOrCreate(['slug' => self::SANS_LIEU], ['nom' => 'Sans lieu', 'type' => 'Autres']);
    }

    /** Ce lieu a une position (il est sur la carte). */
    public function estSitue(): bool
    {
        return $this->latitude !== null && $this->longitude !== null;
    }

    public function uniqueIds(): array
    {
        return ['ulid'];
    }

    public function getRouteKeyName(): string
    {
        return 'slug';
    }

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'nombre_contenus' => 'integer',
            'nombre_reels' => 'integer',
            'nombre_verifiees' => 'integer',
        ];
    }

    /** @return BelongsTo<Ville, $this> */
    public function ville(): BelongsTo
    {
        return $this->belongsTo(Ville::class);
    }

    /** @return HasMany<Contenu, $this> */
    public function contenus(): HasMany
    {
        return $this->hasMany(Contenu::class);
    }

    /**
     * Les photos et vidéos publiées les plus aimées : la pile de l'accueil (une vidéo y passe
     * par son affiche, et se lit sans le son, en boucle) et le haut de la page du lieu.
     */
    public function meilleures(): HasMany
    {
        // Avec leur auteur et leur fiche de prise : la page d'une photo ouverte depuis la pile
        // montre tout de suite qui l'a prise, quand et avec quoi.
        return $this->contenus()->publies()->horsReels()
            ->with(['auteur', 'capture.modele'])
            ->orderByDesc('score')->orderByDesc('nombre_reactions')->orderByDesc('id');
    }

    /** Le contenu publié le mieux noté, photo ou reel : l'image d'un lieu qui n'a que des reels. */
    public function vitrine(): HasMany
    {
        return $this->contenus()->publies()->with(['auteur', 'capture.modele'])->orderByDesc('score')->orderByDesc('id');
    }

    /** @return BelongsToMany<Utilisateur, $this> */
    public function enregistrePar(): BelongsToMany
    {
        return $this->belongsToMany(Utilisateur::class, 'lieux_enregistres')->withTimestamps();
    }

    protected static function booted(): void
    {
        static::saving(function (Lieu $l) {
            if ($l->isDirty(['nom', 'ville_id']) || $l->recherche === null || $l->recherche === '') {
                $ville = $l->ville_id ? Ville::find($l->ville_id) : null;
                $l->recherche = self::normaliser("{$l->nom} {$ville?->nom} {$ville?->region}");
            }
        });
    }

    /** « Lac Ahémé, Possotomé » → « lac aheme possotome » : ce que la recherche compare. */
    public static function normaliser(string $texte): string
    {
        return trim((string) preg_replace('/[^a-z0-9]+/', ' ', Str::lower(Str::ascii($texte))));
    }

    /** Sans passer par les événements (données de départ, migration). */
    public function rafraichirRecherche(): void
    {
        $ville = $this->relationLoaded('ville') ? $this->ville : Ville::find($this->ville_id);
        $this->newQuery()->whereKey($this->id)->update(['recherche' => self::normaliser("{$this->nom} {$ville?->nom} {$ville?->region}")]);
    }

    /** « Mono, Bénin » (vide sans ville) ; la ville et son pays doivent être chargés. */
    public function region(): string
    {
        if ($this->ville === null) {
            return '';
        }

        return collect([$this->ville->region ?? $this->ville->nom, $this->ville->pays?->nom])->filter()->implode(', ');
    }
}
