<?php

namespace App\Http\Requests\Compte;

use Illuminate\Foundation\Http\FormRequest;

/**
 * La base des requêtes du compte : ouvertes à tous (on n'est pas encore connecté), l'e-mail
 * nettoyé avant d'être validé (espaces, majuscules), comme le fait l'application.
 */
abstract class RequeteCompte extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->input('email'))) {
            $this->merge(['email' => mb_strtolower(trim($this->input('email')))]);
        }
    }

    protected static function email(): array
    {
        return ['required', 'string', 'email:rfc', 'max:190'];
    }
}
