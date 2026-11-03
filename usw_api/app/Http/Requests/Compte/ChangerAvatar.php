<?php

namespace App\Http\Requests\Compte;

/** POST moi/avatar : une photo, 8 Mo au plus. */
class ChangerAvatar extends RequeteCompte
{
    public function rules(): array
    {
        return ['avatar' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp,heic,heif', 'max:8192']];
    }
}
