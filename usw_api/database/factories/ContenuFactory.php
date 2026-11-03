<?php

namespace Database\Factories;

use App\Enums\Badge;
use App\Enums\SourceCapture;
use App\Enums\StatutContenu;
use App\Enums\TypeContenu;
use App\Enums\UsageVariante;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\ModeleTelephone;
use App\Models\Utilisateur;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Contenu> */
class ContenuFactory extends Factory
{
    protected $model = Contenu::class;

    public function definition(): array
    {
        return [
            'utilisateur_id' => Utilisateur::factory(),
            'lieu_id' => Lieu::factory(),
            'type' => TypeContenu::Photo,
            'statut' => StatutContenu::Publie,
            'badge' => Badge::Verifiee,
            'legende' => fake()->sentence(),
            'largeur' => 3000,
            'hauteur' => 4000,
            'publie_le' => fake()->dateTimeBetween('-60 days'),
        ];
    }

    public function brouillon(): static
    {
        return $this->state(fn () => ['statut' => StatutContenu::Brouillon, 'publie_le' => null, 'badge' => null]);
    }

    /** Un reel : filmé avec l'appareil photo de Discover (sa capture le dit). */
    public function reel(): static
    {
        return $this->state(fn () => ['type' => TypeContenu::Reel, 'duree' => 24, 'son' => 'Son d’origine', 'largeur' => 1080, 'hauteur' => 1920])
            ->afterCreating(function (Contenu $c) {
                if (! $c->capture()->exists()) {
                    $c->capture()->create(['source' => SourceCapture::Appareil, 'prise_le' => now()->subDay(), 'origines' => ['modele' => 'appareil', 'date' => 'appareil', 'position' => 'appareil']]);
                }
            });
    }

    /** Avec sa capture (un téléphone, une date, une position) et ses tailles d'image. */
    public function complet(?ModeleTelephone $modele = null): static
    {
        return $this->afterCreating(function (Contenu $c) use ($modele) {
            $c->capture()->updateOrCreate([], [
                'source' => $c->type === TypeContenu::Reel ? SourceCapture::Appareil : SourceCapture::Fichier,
                'modele_telephone_id' => ($modele ?? ModeleTelephone::factory()->create())->id,
                'prise_le' => now()->subDays(3),
                'latitude' => 6.28,
                'longitude' => 1.82,
                'origines' => ['modele' => 'exif', 'date' => 'exif', 'position' => 'exif'],
            ]);
            foreach ([UsageVariante::Petite, UsageVariante::Ecran] as $usage) {
                $c->variantes()->create(['usage' => $usage, 'chemin' => "contenus/{$c->ulid}/{$usage->value}.webp", 'largeur' => (int) $usage->value, 'hauteur' => (int) $usage->value * 4 / 3]);
            }
        });
    }
}
