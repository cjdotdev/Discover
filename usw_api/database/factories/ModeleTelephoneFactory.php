<?php

namespace Database\Factories;

use App\Models\ModeleTelephone;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<ModeleTelephone> */
class ModeleTelephoneFactory extends Factory
{
    protected $model = ModeleTelephone::class;

    public function definition(): array
    {
        return ['marque' => fake()->randomElement(['Tecno', 'Infinix', 'Samsung', 'Xiaomi', 'itel']), 'nom' => 'Modèle '.fake()->unique()->numberBetween(1, 99999)];
    }
}
