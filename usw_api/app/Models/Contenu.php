<?php

namespace App\Models;

use App\Enums\Badge;
use App\Enums\SourceCapture;
use App\Enums\StatutContenu;
use App\Enums\TypeContenu;
use App\Observers\ContenuObserver;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\ObservedBy;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Facades\DB;

/** Une photo ou un reel (E05, E06), pris sur place. Il se montre par son ulid. */
#[Fillable(['utilisateur_id', 'lieu_id', 'nom_lieu', 'type', 'portee', 'statut', 'motif', 'manque', 'badge', 'titre', 'legende', 'duree', 'son', 'son_id', 'son_debut_ms', 'son_volume', 'origine_volume', 'largeur', 'hauteur', 'publie_le', 'recours_le'])]
#[ObservedBy(ContenuObserver::class)]
class Contenu extends Model
{
    use HasFactory, HasUlids;

    protected $table = 'contenus';

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
        return [
            'type' => TypeContenu::class,
            'statut' => StatutContenu::class,
            'badge' => Badge::class,
            'publie_le' => 'datetime',
            'recours_le' => 'datetime',
            'etiquete_le' => 'datetime',
            'manque' => 'array',
        ];
    }

    /** @param Builder<Contenu> $requete */
    /**
     * Les reels : seulement les vidéos filmées avec l'appareil photo de Discover (source « appareil »).
     * Une vidéo importée de la galerie n'en est pas un : elle passe dans la pile de son lieu.
     */
    public function scopeReels(Builder $requete): void
    {
        $requete->where('type', TypeContenu::Reel)
            ->whereHas('capture', fn ($c) => $c->where('source', SourceCapture::Appareil));
    }

    /**
     * Tout sauf les reels filmés dans Discover : ils ne se voient que dans les Reels (et sur le
     * profil de leur créateur), pas dans les piles de l'accueil, d'un lieu ni la recherche.
     */
    public function scopeHorsReels(Builder $requete): void
    {
        $requete->where(fn ($q) => $q->where('type', '!=', TypeContenu::Reel)
            ->orWhereDoesntHave('capture', fn ($c) => $c->where('source', SourceCapture::Appareil)));
    }

    /** Une publication du lifestyle de son auteur : hors de l'accueil, des lieux, des Reels et de la recherche. */
    public const LIFESTYLE = 'lifestyle';

    /**
     * En ligne, pour tous (l'accueil, les lieux, les Reels, la recherche, les profils) : pas celles
     * d'un compte suspendu, ni celles d'un lifestyle (elles ne se voient que dans le lifestyle).
     */
    public function scopePublies(Builder $requete): void
    {
        $requete->where('statut', StatutContenu::Publie)->where('portee', '!=', self::LIFESTYLE)
            ->whereNotIn('utilisateur_id', fn ($q) => $q->select('id')->from('utilisateurs')->whereNotNull('suspendu_le'));
    }

    /** En ligne dans le lifestyle de leur auteur (pas d'un compte suspendu). */
    public function scopeDuLifestyle(Builder $requete): void
    {
        $requete->where('statut', StatutContenu::Publie)->where('portee', self::LIFESTYLE)
            ->whereNotIn('utilisateur_id', fn ($q) => $q->select('id')->from('utilisateurs')->whereNotNull('suspendu_le'));
    }

    public function estDuLifestyle(): bool
    {
        return $this->portee === self::LIFESTYLE;
    }

    public function estPublie(): bool
    {
        return $this->statut === StatutContenu::Publie;
    }

    /** Le temps laissé à l'auteur pour modifier une publication en ligne ; ensuite, il ne peut que la supprimer. */
    public const DELAI_MODIFICATION_MINUTES = 60;

    /** Encore modifiable : pas encore en ligne (à compléter, en vérification), ou en ligne depuis moins d'une heure. */
    public function modifiable(): bool
    {
        return ! $this->estPublie() || $this->publie_le === null || $this->publie_le->gt(now()->subMinutes(self::DELAI_MODIFICATION_MINUTES));
    }

    /** Visible de tous : publié, et son auteur n'est pas suspendu (la règle de scopePublies). */
    public function estVisible(): bool
    {
        // Une publication de lifestyle : seulement si son auteur a rendu son lifestyle visible.
        return $this->estPublie() && Utilisateur::whereKey($this->utilisateur_id)->whereNull('suspendu_le')
            ->when($this->estDuLifestyle(), fn ($q) => $q->where('lifestyle_visible', true))->exists();
    }

    /** @return BelongsTo<Utilisateur, $this> */
    public function auteur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }

    /** @return BelongsTo<Lieu, $this> */
    public function lieu(): BelongsTo
    {
        return $this->belongsTo(Lieu::class);
    }

    /** @return HasMany<Etiquette, $this> */
    public function etiquettes(): HasMany
    {
        return $this->hasMany(Etiquette::class);
    }

    /**
     * Ce que le téléphone a vu sur la photo : remplace les étiquettes d'avant (20 au plus, les plus
     * sûres d'abord).
     *
     * @param  list<array{nom: string, confiance: float|int}>  $etiquettes
     */
    public function etiqueter(array $etiquettes): void
    {
        $lignes = collect($etiquettes)
            ->map(fn ($e) => ['nom' => mb_strtolower(trim((string) $e['nom'])), 'confiance' => round((float) $e['confiance'], 3)])
            ->filter(fn ($e) => $e['nom'] !== '')->sortByDesc('confiance')->unique('nom')->take(20)
            ->map(fn ($e) => [...$e, 'contenu_id' => $this->id])->values()->all();
        DB::transaction(function () use ($lignes) {
            $this->etiquettes()->delete();
            if ($lignes !== []) {
                Etiquette::insert($lignes);
            }
            $this->newQuery()->whereKey($this->id)->toBase()->update(['etiquete_le' => now()]);
        });
    }

    /** @return BelongsTo<Son, $this> */
    public function musique(): BelongsTo
    {
        return $this->belongsTo(Son::class, 'son_id');
    }

    /** @return HasOne<Capture, $this> */
    public function capture(): HasOne
    {
        return $this->hasOne(Capture::class);
    }

    /** @return HasOne<FichierOriginal, $this> */
    public function original(): HasOne
    {
        return $this->hasOne(FichierOriginal::class);
    }

    /** @return HasMany<Variante, $this> */
    public function variantes(): HasMany
    {
        return $this->hasMany(Variante::class);
    }

    /** @return HasMany<Envoi, $this> */
    public function envois(): HasMany
    {
        return $this->hasMany(Envoi::class);
    }

    /** Largeur sur hauteur, pour réserver la place avant l'image. */
    /** @return HasMany<Reaction, $this> */
    public function reactions(): HasMany
    {
        return $this->hasMany(Reaction::class);
    }

    /** @return HasMany<Commentaire, $this> */
    public function commentaires(): HasMany
    {
        return $this->hasMany(Commentaire::class);
    }

    /**
     * Ce que le membre connecté en dit, pour une liste entière d'un coup (sans requête par
     * contenu) : sa réaction et s'il l'a enregistré.
     */
    public function scopeAvecMoi(Builder $q, ?Utilisateur $u): void
    {
        if ($u === null) {
            return;
        }
        if ($q->getQuery()->columns === null) {
            $q->select('contenus.*');
        }
        $q->addSelect([
            'ma_reaction' => Reaction::select('type')->whereColumn('contenu_id', 'contenus.id')->where('utilisateur_id', $u->id)->limit(1),
            'enregistre_par_moi' => DB::table('enregistrements')
                ->join('collections', 'collections.id', '=', 'enregistrements.collection_id')
                ->whereColumn('enregistrements.contenu_id', 'contenus.id')
                ->where('collections.utilisateur_id', $u->id)
                ->selectRaw('count(*)'),
        ]);
    }

    /** Sans les contenus des membres que l'on a bloqués. */
    public function scopeSansBloques(Builder $q, ?Utilisateur $u): void
    {
        if ($u !== null) {
            $q->whereNotIn('contenus.utilisateur_id', Blocage::where('bloqueur_id', $u->id)->select('bloque_id'));
        }
    }

    public function ratio(): ?float
    {
        return $this->largeur && $this->hauteur ? round($this->largeur / $this->hauteur, 4) : null;
    }
}
