<?php

namespace App\Http\Requests\Compte;

use Illuminate\Validation\Rule;

/** PATCH moi : le profil (« Compléter le profil », « Modifier le profil »). */
class ModifierProfil extends RequeteCompte
{
    protected function prepareForValidation(): void
    {
        if (is_string($this->input('nom_utilisateur'))) {
            $this->merge(['nom_utilisateur' => mb_strtolower(ltrim(trim($this->input('nom_utilisateur')), '@'))]);
        }
    }

    public function rules(): array
    {
        return [
            'nom_affiche' => ['sometimes', 'string', 'min:2', 'max:60'],
            'nom_utilisateur' => ['sometimes', 'string', 'min:3', 'max:30', 'regex:/^[a-z0-9._]+$/', Rule::unique('utilisateurs', 'nom_utilisateur')->ignore($this->user()?->id)],
            'bio' => ['sometimes', 'nullable', 'string', 'max:160'],
            'site' => ['sometimes', 'nullable', 'string', 'max:120'],
            'pays' => ['sometimes', 'nullable', 'string', 'max:60'],
            'ville' => ['sometimes', 'nullable', 'string', 'max:60'],
            'position' => ['sometimes', 'boolean'],
            'types_aimes' => ['sometimes', 'array', 'max:12'],
            'types_aimes.*' => ['string', 'max:40'],
            'profil_complete' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return ['nom_utilisateur.regex' => 'Le nom d’utilisateur ne peut contenir que des lettres minuscules, des chiffres, des points et des tirets bas.'];
    }
}
