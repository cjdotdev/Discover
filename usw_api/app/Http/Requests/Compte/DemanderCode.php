<?php

namespace App\Http\Requests\Compte;

/** POST auth/code/envoyer : l'adresse où envoyer le code à 6 chiffres. */
class DemanderCode extends RequeteCompte
{
    public function rules(): array
    {
        return ['email' => self::email(), 'defi' => ['nullable', 'string', 'regex:/^[A-Za-z0-9]{40}$/']];
    }
}
