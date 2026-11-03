<?php

namespace App\Http\Requests\Contenus;

use App\Models\ModeleTelephone;
use Closure;
use Illuminate\Foundation\Http\FormRequest;

/** POST modeles-telephone : un téléphone que la liste n'a pas encore (E15). */
class AjouterModele extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'marque' => is_string($this->marque) ? trim((string) preg_replace('/\s+/', ' ', $this->marque)) : $this->marque,
            'nom' => is_string($this->nom) ? trim((string) preg_replace('/\s+/', ' ', $this->nom)) : $this->nom,
        ]);
    }

    public function rules(): array
    {
        return [
            'marque' => ['required', 'string', 'min:2', 'max:60'],
            'nom' => ['required', 'string', 'min:1', 'max:100', function (string $attribut, mixed $valeur, Closure $echec) {
                // « tecno CAMON-50 pro » est le même téléphone que « Tecno Camon 50 Pro ».
                if (ModeleTelephone::where('nom_recherche', ModeleTelephone::normaliser($this->marque.' '.$valeur))->exists()) {
                    $echec('Ce téléphone est déjà dans la liste.');
                }
            }],
        ];
    }

    public function attributes(): array
    {
        return ['marque' => 'marque', 'nom' => 'modèle'];
    }
}
