<?php

namespace App\Http\Requests\Compte;

/** POST auth/google : le jeton d'identité obtenu par l'application. */
class ConnexionGoogle extends RequeteCompte
{
    public function rules(): array
    {
        return ['jeton' => ['required', 'string', 'max:4096'], 'appareil' => ['nullable', 'string', 'max:60']];
    }
}
