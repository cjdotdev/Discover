<?php

namespace App\Http\Requests\Contenus;

use Illuminate\Foundation\Http\FormRequest;

/** PATCH contenus/{contenu} : ce que le fichier ne disait pas (E15), le lieu (E30), le texte. */
class CompleterContenu extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'titre' => ['sometimes', 'nullable', 'string', 'max:120'],
            'legende' => ['sometimes', 'nullable', 'string', 'max:2200'],
            'marque' => ['sometimes', 'string', 'max:60', 'required_with:modele'],
            'modele' => ['sometimes', 'string', 'max:100', 'required_with:marque'],
            'prise_le' => ['sometimes', 'date', 'after_or_equal:1990-01-01', 'before_or_equal:'.now()->addDay()->toDateString()],
            'lieu' => ['sometimes', 'string', 'exists:lieux,slug'],
            'lieu_google' => ['sometimes', 'string', 'max:300'],
            'lieu_latitude' => ['sometimes', 'numeric', 'between:-90,90', 'required_with:lieu_longitude'],
            'lieu_longitude' => ['sometimes', 'numeric', 'between:-180,180', 'required_with:lieu_latitude'],
            'lieu_nom' => ['sometimes', 'string', 'max:160'],
            'nom_lieu' => ['sometimes', 'nullable', 'string', 'max:160'],
            'ville' => ['sometimes', 'nullable', 'string', 'max:120'],
            'region' => ['sometimes', 'nullable', 'string', 'max:120'],
            'pays' => ['sometimes', 'nullable', 'string', 'max:80'],
            'pays_code' => ['sometimes', 'nullable', 'string', 'size:2'],
        ];
    }

    public function messages(): array
    {
        return ['prise_le.before_or_equal' => 'La date de prise ne peut pas être dans le futur.', 'lieu.exists' => 'Ce lieu est inconnu.'];
    }
}
