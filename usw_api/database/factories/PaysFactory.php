<?php

namespace Database\Factories;

use App\Models\Pays;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Pays> */
class PaysFactory extends Factory
{
    protected $model = Pays::class;

    public function definition(): array
    {
        return ['code' => fake()->unique()->countryCode(), 'nom' => fake()->country()];
    }
}
