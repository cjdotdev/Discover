<?php

namespace App\Http\Requests\Contenus;

use Illuminate\Foundation\Http\FormRequest;

/** GET modeles-telephone?q=camon */
class ChercherModeles extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['q' => ['required', 'string', 'min:1', 'max:60']];
    }
}
