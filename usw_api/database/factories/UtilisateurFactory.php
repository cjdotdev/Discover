<?php

namespace Database\Factories;

use App\Models\Utilisateur;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Utilisateur>
 */
class UtilisateurFactory extends Factory
{
    protected $model = Utilisateur::class;

    public function definition(): array
    {
        $nom = fake()->firstName();

        return [
            'email' => fake()->unique()->safeEmail(),
            'fournisseur' => 'email',
            'email_verifie_le' => now(),
            'nom_affiche' => $nom,
            'nom_utilisateur' => Str::lower(Str::ascii($nom)).fake()->unique()->numberBetween(10, 9999),
            'pays' => 'Bénin',
            'ville' => 'Cotonou',
        ];
    }

    /** L'adresse n'a pas encore été confirmée par le code. */
    public function nonVerifie(): static
    {
        return $this->state(fn () => ['email_verifie_le' => null]);
    }

    /** Un compte ouvert avec Google. */
    public function google(): static
    {
        return $this->state(fn () => ['fournisseur' => 'google', 'google_sub' => (string) fake()->unique()->numberBetween(1e9, 9e9)]);
    }
}
