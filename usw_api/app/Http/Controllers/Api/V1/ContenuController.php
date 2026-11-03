<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\StatutContenu;
use App\Enums\UsageVariante;
use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Requests\Contenus\CompleterContenu;
use App\Http\Requests\Contenus\CreerContenu;
use App\Http\Resources\ContenuResource;
use App\Jobs\AnalyserCapture;
use App\Models\Contenu;
use App\Models\Envoi;
use App\Models\Lieu;
use App\Services\Contenus\Publication;
use App\Support\Medias;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\URL;

/** Les contenus (E05, E06). */
class ContenuController extends Controller
{
    public const DELAI_RECOURS_JOURS = 30;

    /** GET contenus/{contenu} : ouvert aux visiteurs s'il est publié ; sinon à son auteur seul. */
    public function afficher(Request $requete, Contenu $contenu): ContenuResource
    {
        Gate::forUser($requete->user('sanctum'))->authorize('voir', $contenu);
        // Avec la part du membre (sa réaction, son enregistrement), relue en une requête.
        $contenu = Contenu::whereKey($contenu->id)->avecMoi($requete->user('sanctum'))
            ->with(['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes'])->firstOrFail();

        return new ContenuResource($contenu);
    }

    /**
     * POST contenus/{contenu}/verification : l'auteur d'une publication refusée demande une seconde
     * vérification, par l'équipe. Une fois par publication, dans les 30 jours (ses fichiers sont
     * gardés jusque-là). Il reçoit la décision comme d'habitude, par une notification.
     */
    public function verification(Request $requete, Contenu $contenu): JsonResponse
    {
        if ($contenu->utilisateur_id !== $requete->user()->id) {
            throw new ErreurMetier(403, 'Seul l’auteur de la publication peut demander une vérification.');
        }
        if ($contenu->statut !== StatutContenu::Refuse) {
            throw new ErreurMetier(422, 'Cette publication n’est pas refusée.');
        }
        if ($contenu->recours_le !== null) {
            throw new ErreurMetier(422, 'Vous avez déjà demandé une seconde vérification pour cette publication.');
        }
        if ($contenu->updated_at !== null && $contenu->updated_at->lt(now()->subDays(self::DELAI_RECOURS_JOURS))) {
            throw new ErreurMetier(422, 'Le délai de 30 jours pour demander une seconde vérification est dépassé.');
        }
        $contenu->update(['statut' => StatutContenu::FileHumaine, 'recours_le' => now()]);

        return response()->json(['message' => __('Demande envoyée. L’équipe va revoir votre publication.')]);
    }

    /** POST contenus : le brouillon et ses deux envois à remplir (l'aperçu, puis l'original). */
    public function creer(CreerContenu $requete, Publication $publication): JsonResponse
    {
        $contenu = $publication->creer($requete->user(), $requete->validated());
        $contenu->load(['lieu.ville.pays', 'capture.modele', 'envois']);

        return response()->json([
            'contenu' => new ContenuResource($contenu),
            'envois' => $contenu->envois->mapWithKeys(fn (Envoi $e) => [$e->role->value => ['id' => $e->ulid, 'decalage' => $e->recu, 'taille' => $e->taille]]),
        ], 201);
    }

    /** PATCH contenus/{contenu} : compléter ; s'il attendait ces informations, l'analyse repart. */
    public function modifier(CompleterContenu $requete, Contenu $contenu, Publication $publication): ContenuResource
    {
        Gate::authorize('modifier', $contenu);
        if (! $contenu->modifiable()) {
            throw new ErreurMetier(422, 'Une publication ne se modifie plus après 1 h. Vous pouvez la supprimer.');
        }
        $publication->completer($contenu, $requete->user(), $requete->validated());
        if ($contenu->statut === StatutContenu::ACompleter) {
            AnalyserCapture::dispatch($contenu);
        }
        $contenu->refresh()->load(['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes']);

        return new ContenuResource($contenu);
    }

    /** DELETE contenus/{contenu} : le contenu, ses fichiers (privés et publics) et ses envois. */
    public function supprimer(Contenu $contenu): Response
    {
        Gate::authorize('modifier', $contenu);
        Medias::effacer($contenu);
        $contenu->delete();

        return response()->noContent();
    }

    /**
     * GET contenus/{contenu}/original : télécharger. L'original quand le serveur le garde (un lien
     * signé, valable 10 minutes) ; sinon la plus grande taille servie (2 160 px, ou la vidéo).
     */
    public function original(Request $requete, Contenu $contenu): JsonResponse
    {
        Gate::forUser($requete->user('sanctum'))->authorize('voir', $contenu);
        $expire = now()->addMinutes(10);
        $original = $contenu->original()->first();
        $auteur = $requete->user('sanctum')?->id === $contenu->utilisateur_id;
        $positionPublique = $contenu->lieu?->slug !== Lieu::SANS_LIEU;
        // Une taille demandée (?taille=1080) passe avant l'original.
        if ($original?->chemin !== null && ($auteur || $positionPublique) && ! $requete->filled('taille')) {
            $url = config('discover.originaux') === 'local'
                ? URL::temporarySignedRoute('originaux.telecharger', $expire, ['contenu' => $contenu->ulid])
                : Medias::originaux()->temporaryUrl($original->chemin, $expire);

            return response()->json(['url' => $url, 'original' => true, 'expire_le' => $expire->toIso8601String()]);
        }
        $variantes = $contenu->variantes()->get();
        // ?taille=1080|2160|3840 : la taille choisie au téléchargement, si elle existe.
        $choisie = UsageVariante::tryFrom((string) $requete->query('taille'));
        $plusGrande = ($choisie && $choisie !== UsageVariante::Flou ? $variantes->firstWhere('usage', $choisie) : null) ?? $variantes
            ->sortBy(fn ($v) => array_search($v->usage, [UsageVariante::VideoHd, UsageVariante::Video, UsageVariante::TresGrande, UsageVariante::Grande, UsageVariante::Ecran, UsageVariante::Affiche, UsageVariante::Petite], true))
            ->first(fn ($v) => ! in_array($v->usage, [UsageVariante::Flou, UsageVariante::VideoApercu], true));
        abort_if($plusGrande === null, 404);

        return response()->json(['url' => $plusGrande->url(), 'original' => false, 'expire_le' => null]);
    }
}
