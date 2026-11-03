<?php

namespace App\Http\Requests\Contenus;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** GET lieux/{lieu}/contenus?type=reel&curseur=… */
class ContenusDuLieu extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['nullable', Rule::in(['photo', 'reel'])],
            'curseur' => ['nullable', 'string', 'max:500'],
        ];
    }
}
