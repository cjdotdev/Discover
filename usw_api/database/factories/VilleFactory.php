<?php

namespace Database\Factories;

use App\Models\Pays;
use App\Models\Ville;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Ville> */
class VilleFactory extends Factory
{
    protected $model = Ville::class;

    public function definition(): array
    {
        return ['pays_id' => Pays::factory(), 'nom' => fake()->unique()->city(), 'region' => ucfirst(fake()->word())];
    }
}
