<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

/** Un modèle de téléphone (B24) : « Tecno » « Camon 50 Pro ». */
#[Fillable(['marque', 'nom', 'ajoute_par'])]
class ModeleTelephone extends Model
{
    use HasFactory;

    protected $table = 'modeles_telephone';

    // La forme cherchable suit la marque et le nom, sans evenement : les donnees de depart
    // s inserent sans evenements (WithoutModelEvents).
    protected function marque(): Attribute
    {
        return Attribute::set(fn (string $v, array $a) => ['marque' => $v, 'nom_recherche' => self::normaliser($v.' '.($a['nom'] ?? ''))]);
    }

    protected function nom(): Attribute
    {
        return Attribute::set(fn (string $v, array $a) => ['nom' => $v, 'nom_recherche' => self::normaliser(($a['marque'] ?? '').' '.$v)]);
    }

    /** « TECNO  Camon-50 Pro » -> « tecno camon 50 pro » : sans accents, majuscules ni ponctuation. */
    public static function normaliser(string $texte): string
    {
        return trim((string) preg_replace('/[^a-z0-9]+/', ' ', Str::lower(Str::ascii($texte))));
    }

    /** @return BelongsTo<Utilisateur, $this> */
    public function ajoutePar(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'ajoute_par');
    }

    public function complet(): string
    {
        // « Apple iPhone 13 » se dit « iPhone 13 » : la marque est dans le nom.
        return Str::startsWith(Str::lower($this->nom), Str::lower($this->marque)) || $this->marque === 'Apple'
            ? $this->nom
            : $this->marque.' '.$this->nom;
    }
}
