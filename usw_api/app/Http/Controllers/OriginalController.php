<?php

namespace App\Http\Controllers;

use App\Models\Contenu;
use App\Support\Medias;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/** Le fichier original, servi seulement par un lien signé et encore valable (B35). */
class OriginalController extends Controller
{
    public function __invoke(Contenu $contenu): BinaryFileResponse
    {
        abort_unless($contenu->estVisible(), 404);
        $original = $contenu->original()->whereNotNull('chemin')->firstOrFail();
        $nom = 'discover-'.$contenu->ulid.'.'.$original->format;

        return response()->download(Medias::originaux()->path($original->chemin), $nom, ['Cache-Control' => 'private, no-store']);
    }
}
