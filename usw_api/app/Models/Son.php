<?php

namespace App\Models;

use App\Support\Medias;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Un son du catalogue, à mettre sur un reel. Il se montre par son ulid. */
#[Fillable(['cle', 'titre', 'artiste', 'categorie', 'duree_ms', 'chemin', 'forme', 'debut_conseille_ms', 'licence', 'licence_url', 'attribution', 'actif', 'utilisateur_id'])]
class Son extends Model
{
    use HasUlids;

    protected $table = 'sons';

    /** Les ambiances du catalogue, dans l'ordre où l'application les propose. */
    public const CATEGORIES = ['afro', 'joyeux', 'energie', 'plage', 'calme', 'aventure'];

    /** La categorie des sons importés par les membres (le son d'une vidéo, un fichier du téléphone). */
    public const MEMBRES = 'membres';

    /** Signalé par autant de membres, un son importé est retiré. */
    public const SIGNALEMENTS_MAX = 3;

    public function uniqueIds(): array
    {
        return ['ulid'];
    }

    public function getRouteKeyName(): string
    {
        return 'ulid';
    }

    protected function casts(): array
    {
        return ['forme' => 'array', 'actif' => 'boolean', 'duree_ms' => 'integer', 'debut_conseille_ms' => 'integer', 'nombre_reels' => 'integer'];
    }

    public function url(): string
    {
        return Medias::public()->url($this->chemin);
    }

    /** « Allada · Kevin MacLeod » : ce que le reel affiche sous la légende. */
    public function nomComplet(): string
    {
        return "{$this->titre} · {$this->artiste}";
    }

    /** @param Builder<Son> $requete */
    public function scopeActifs(Builder $requete): void
    {
        $requete->where('actif', true);
    }

    /** @return HasMany<Contenu, $this> */
    public function contenus(): HasMany
    {
        return $this->hasMany(Contenu::class);
    }

    /** @return BelongsToMany<Utilisateur, $this> */
    public function favoriDe(): BelongsToMany
    {
        return $this->belongsToMany(Utilisateur::class, 'sons_favoris')->withTimestamps();
    }

    protected static function booted(): void
    {
        static::saving(function (Son $s) {
            $s->recherche = Lieu::normaliser("{$s->titre} {$s->artiste}");
        });
    }
}
