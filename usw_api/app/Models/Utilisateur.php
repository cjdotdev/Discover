<?php

namespace App\Models;

use App\Enums\StatutContenu;
use Database\Factories\UtilisateurFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

/**
 * Un membre de Discover. Il entre avec un code reçu par e-mail ou avec Google : pas de mot de passe. Il se montre par son `ulid` (jamais par son numéro) et par son nom d'utilisateur.
 */
#[Fillable([
    'email', 'fournisseur', 'google_sub', 'email_verifie_le',
    'nom_affiche', 'nom_utilisateur', 'bio', 'site', 'pays', 'ville', 'position', 'types_aimes',
    'avatar', 'profil_complete_le', 'lifestyle_visible',
])]
#[Hidden(['google_sub'])]
class Utilisateur extends Authenticatable
{
    /** @use HasFactory<UtilisateurFactory> */
    use HasApiTokens, HasFactory, HasUlids, Notifiable;

    protected $table = 'utilisateurs';

    /** Le numéro reste la clé ; l'ulid est rempli à la création. */
    public function uniqueIds(): array
    {
        return ['ulid'];
    }

    protected function casts(): array
    {
        return [
            'email_verifie_le' => 'datetime',
            'profil_complete_le' => 'datetime',
            'suppression_demandee_le' => 'datetime',
            'derniere_activite_le' => 'datetime',
            'suspendu_le' => 'datetime',
            'position' => 'boolean',
            'lifestyle_visible' => 'boolean',
            'types_aimes' => 'array',
        ];
    }

    public function estVerifie(): bool
    {
        return $this->email_verifie_le !== null;
    }

    /** Les jours de grâce avant l'effacement d'un compte dont la suppression est demandée. */
    public const JOURS_AVANT_SUPPRESSION = 30;

    /** @return HasMany<Collection, $this> */
    /** Les lieux qu'il a enregistrés pour y aller plus tard. */
    public function lieuxEnregistres(): BelongsToMany
    {
        return $this->belongsToMany(Lieu::class, 'lieux_enregistres')->withTimestamps();
    }

    /** Les sons qu'il a mis de côté pour ses prochains reels. */
    public function sonsFavoris(): BelongsToMany
    {
        return $this->belongsToMany(Son::class, 'sons_favoris')->withTimestamps();
    }

    public function collections(): HasMany
    {
        return $this->hasMany(Collection::class);
    }

    /** L'équipe de Discover : une adresse de ADMIN_EMAILS (config/discover.php), rien sur le compte. */
    public function estAdmin(): bool
    {
        return in_array(mb_strtolower((string) $this->email), config('discover.admins'), true);
    }

    public function estSuspendu(): bool
    {
        return $this->suspendu_le !== null;
    }

    protected static function booted(): void
    {
        // La recherche des membres (Gérer Discover) suit le nom, l'adresse et la ville.
        static::saving(function (Utilisateur $u) {
            $u->recherche = self::texteDeRecherche($u);
        });
    }

    /** Ce que l'on cherche d'un membre, sans accents ni majuscules. */
    public static function texteDeRecherche(object $u): string
    {
        return Str::limit(self::normaliser(implode(' ', array_filter([$u->nom_affiche, $u->nom_utilisateur, $u->email, $u->ville, $u->pays]))), 400, '');
    }

    public static function normaliser(string $texte): string
    {
        return Str::lower(Str::ascii($texte));
    }

    public function suit(Utilisateur $createur): bool
    {
        return Abonnement::where('abonne_id', $this->id)->where('createur_id', $createur->id)->exists();
    }

    public function aBloque(Utilisateur $autre): bool
    {
        return Blocage::where('bloqueur_id', $this->id)->where('bloque_id', $autre->id)->exists();
    }

    /** @return HasMany<AppareilPush, $this> */
    public function appareilsPush(): HasMany
    {
        return $this->hasMany(AppareilPush::class);
    }

    /** @return HasMany<Contenu, $this> */
    public function contenus(): HasMany
    {
        return $this->hasMany(Contenu::class);
    }

    /** Son lifestyle en ligne, le plus récent d'abord. @return HasMany<Contenu, $this> */
    public function lifestyle(): HasMany
    {
        return $this->hasMany(Contenu::class)->where('statut', StatutContenu::Publie)->where('portee', Contenu::LIFESTYLE)
            ->orderByDesc('publie_le')->orderByDesc('id');
    }
}
