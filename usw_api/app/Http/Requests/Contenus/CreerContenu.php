<?php

namespace App\Http\Requests\Contenus;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * POST contenus : le brouillon, ce que l'application a lu de la prise, et les deux fichiers
 * qu'elle va envoyer (leur taille, leur type, leur empreinte SHA-256).
 */
class CreerContenu extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $origine = Rule::in(['exif', 'appareil', 'declaree']);

        return [
            'type' => ['required', Rule::in(['photo', 'reel'])],
            'portee' => ['nullable', Rule::in(['decouverte', 'lifestyle'])],
            'titre' => ['nullable', 'string', 'max:120'],
            'legende' => ['nullable', 'string', 'max:2200'],
            'duree' => ['nullable', 'required_if:type,reel', 'integer', 'min:1', 'max:60'],
            'son' => ['nullable', 'string', 'max:120'],
            // Un son du catalogue (son identifiant), d'où il part et les deux volumes, de 0 à 100.
            'musique' => ['nullable', 'array'],
            'musique.id' => ['required_with:musique', 'string', Rule::exists('sons', 'ulid')->where('actif', true)],
            'musique.debut_ms' => ['nullable', 'integer', 'min:0'],
            'musique.volume' => ['nullable', 'integer', 'between:0,100'],
            'musique.volume_origine' => ['nullable', 'integer', 'between:0,100'],
            // Ce que le téléphone voit sur la photo (Google ML Kit) : la recherche « arbre » s'en sert.
            'etiquettes' => ['nullable', 'array', 'max:30'],
            'etiquettes.*.nom' => ['required', 'string', 'max:60'],
            'etiquettes.*.confiance' => ['required', 'numeric', 'between:0,1'],
            // Le lieu : un lieu connu (son slug), sinon il est trouvé par la position, ou créé
            // depuis le nom qu'Android donne (quartier, ville, pays).
            'lieu' => ['nullable', 'string', 'max:120'],
            'lieu_nom' => ['nullable', 'string', 'max:160'],
            'ville' => ['nullable', 'string', 'max:120'],
            'region' => ['nullable', 'string', 'max:120'],
            'pays' => ['nullable', 'string', 'max:80'],
            'pays_code' => ['nullable', 'string', 'size:2'],
            // Un lieu trouvé avec Google (son identifiant), un point posé sur la carte, ou un nom
            // seul, sans position (la photo rejoint « Sans lieu »).
            'lieu_google' => ['nullable', 'string', 'max:300'],
            'lieu_latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:lieu_longitude'],
            'lieu_longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:lieu_latitude'],
            'nom_lieu' => ['nullable', 'string', 'max:160'],
            'capture' => ['required', 'array'],
            'capture.source' => ['required', Rule::in(['fichier', 'appareil', 'declaree'])],
            'capture.marque' => ['nullable', 'string', 'max:60'],
            'capture.modele' => ['nullable', 'string', 'max:100'],
            // Jamais dans le futur (un jour de marge pour les fuseaux), jamais avant 1990.
            'capture.prise_le' => ['nullable', 'date', 'after_or_equal:1990-01-01', 'before_or_equal:'.now()->addDay()->toDateString()],
            'capture.latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:capture.longitude'],
            'capture.longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:capture.latitude'],
            'capture.origines' => ['nullable', 'array'],
            'capture.origines.modele' => ['nullable', $origine],
            'capture.origines.date' => ['nullable', $origine],
            'capture.origines.position' => ['nullable', $origine],
            'fichiers' => ['required', 'array'],
            'fichiers.apercu' => ['required', 'array'],
            'fichiers.original' => ['required', 'array'],
            // L'aperçu : un WebP de 2 160 px. L'original : une photo, ou un reel de 60 s (4K non ré-encodée comprise).
            'fichiers.apercu.taille' => ['required', 'integer', 'min:1', 'max:'.(20 * 1024 * 1024)],
            'fichiers.original.taille' => ['required', 'integer', 'min:1', 'max:'.(($this->input('type') === 'reel' ? 400 : 60) * 1024 * 1024)],
            'fichiers.*.type' => ['required', 'string', 'max:60'],
            'fichiers.*.empreinte' => ['required', 'string', 'regex:/^[a-f0-9]{64}$/'],
        ];
    }

    public function messages(): array
    {
        return [
            'duree.max' => 'Un reel dure 60 secondes au plus.',
            'capture.prise_le.before_or_equal' => 'La date de prise ne peut pas être dans le futur.',
            'capture.prise_le.after_or_equal' => 'Cette date de prise n’est pas valide.',
            'fichiers.apercu.taille.max' => 'Cet aperçu est trop lourd.',
            'fichiers.original.taille.max' => $this->input('type') === 'reel' ? 'Cette vidéo dépasse 400 Mo.' : 'Cette photo dépasse 60 Mo.',
        ];
    }
}
