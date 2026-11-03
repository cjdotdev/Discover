<?php

namespace App\Http\Requests\Contenus;

use Illuminate\Foundation\Http\FormRequest;

/** GET lieux/proche?latitude=6.3256&longitude=2.0886 */
class LieuProche extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ];
    }
}
