<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\RoleEnvoi;
use App\Enums\TypeContenu;
use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Jobs\AnalyserCapture;
use App\Models\Envoi;
use App\Services\Envois\Reception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

/** B30 : HEAD (où en est-on ?), PATCH (un morceau), POST terminer. */
class EnvoiController extends Controller
{
    public function __construct(private Reception $reception) {}

    private function entetes(Envoi $envoi): array
    {
        return ['Upload-Offset' => (string) $envoi->recu, 'Upload-Length' => (string) $envoi->taille, 'Cache-Control' => 'no-store'];
    }

    /** HEAD envois/{envoi} : le décalage déjà reçu. C'est la reprise après une coupure. */
    public function etat(Envoi $envoi): Response
    {
        Gate::authorize('envoyer', $envoi);

        return response()->noContent(200)->withHeaders($this->entetes($envoi));
    }

    /** PATCH envois/{envoi} : un morceau brut, à partir de Upload-Offset. */
    public function morceau(Request $requete, Envoi $envoi): Response
    {
        Gate::authorize('envoyer', $envoi);
        if (! str_starts_with((string) $requete->header('Content-Type'), 'application/offset+octet-stream')) {
            throw new ErreurMetier(415, 'Un morceau s’envoie en application/offset+octet-stream.');
        }
        $decalage = $requete->header('Upload-Offset');
        if ($decalage === null || ! ctype_digit((string) $decalage)) {
            throw new ErreurMetier(400, 'Upload-Offset manque.');
        }
        $this->reception->ajouter($envoi, (int) $decalage, $requete->getContent());

        return response()->noContent()->withHeaders($this->entetes($envoi));
    }

    /** POST envois/{envoi}/terminer : vérifié, rangé ; l'analyse part dès qu'il ne manque rien. */
    public function terminer(Envoi $envoi): JsonResponse
    {
        Gate::authorize('envoyer', $envoi);
        // Déjà terminé : on répond pareil, sans relancer l'analyse (un appel répété ne la refait pas).
        $deja = $envoi->estTermine();
        $this->reception->terminer($envoi);
        $contenu = $envoi->contenu()->with('envois')->first();
        $apercu = $contenu->envois->firstWhere('role', RoleEnvoi::Apercu)?->estTermine();
        $original = $contenu->envois->firstWhere('role', RoleEnvoi::Original)?->estTermine();
        // Une photo se publie dès son aperçu ; un reel attend sa vidéo. L'original d'une
        // photo, arrivé ensuite, relance l'analyse (une 2 160 px nette, l'original relu).
        if (! $deja && $apercu && ($contenu->type === TypeContenu::Photo || $original)) {
            AnalyserCapture::dispatch($contenu);
        }

        return response()->json(['statut' => 'termine', 'contenu' => $contenu->ulid]);
    }
}
