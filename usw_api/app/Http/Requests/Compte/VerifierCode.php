<?php

namespace App\Http\Requests\Compte;

/** POST auth/code : le code à 6 chiffres reçu par e-mail. */
class VerifierCode extends RequeteCompte
{
    public function rules(): array
    {
        return [
            'email' => self::email(),
            'code' => ['required', 'string', 'digits:6'],
            'defi' => ['required', 'string', 'regex:/^[A-Za-z0-9]{40}$/'],
            'appareil' => ['nullable', 'string', 'max:60'],
        ];
    }
}
