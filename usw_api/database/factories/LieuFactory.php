<?php

namespace Database\Factories;

use App\Models\Lieu;
use App\Models\Ville;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<Lieu> */
class LieuFactory extends Factory
{
    protected $model = Lieu::class;

    public function definition(): array
    {
        $nom = 'Plage de '.fake()->unique()->city();

        return [
            'slug' => Str::slug($nom),
            'nom' => $nom,
            'ville_id' => Ville::factory(),
            'type' => 'Plages',
            // Le golfe de Guinée, du Togo au Nigeria.
            'latitude' => fake()->randomFloat(6, 6.2, 6.5),
            'longitude' => fake()->randomFloat(6, 1.6, 2.7),
        ];
    }
}
