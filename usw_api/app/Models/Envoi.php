<?php

namespace App\Models;

use App\Enums\RoleEnvoi;
use App\Enums\StatutEnvoi;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Un fichier qui arrive par morceaux (B30). Il se montre par son ulid. */
#[Fillable(['utilisateur_id', 'contenu_id', 'role', 'type', 'taille', 'recu', 'empreinte_sha256', 'statut', 'derniere_activite'])]
class Envoi extends Model
{
    use HasUlids;

    protected $table = 'envois';

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
            'role' => RoleEnvoi::class,
            'statut' => StatutEnvoi::class,
            'taille' => 'integer',
            'recu' => 'integer',
            'derniere_activite' => 'datetime',
        ];
    }

    /** @return BelongsTo<Contenu, $this> */
    public function contenu(): BelongsTo
    {
        return $this->belongsTo(Contenu::class);
    }

    /** @return BelongsTo<Utilisateur, $this> */
    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class);
    }

    public function estTermine(): bool
    {
        return $this->statut === StatutEnvoi::Termine;
    }

    /** Le fichier en cours d'assemblage, sur le disque privé. */
    public function cheminPartiel(): string
    {
        return "envois/{$this->ulid}.part";
    }
}
