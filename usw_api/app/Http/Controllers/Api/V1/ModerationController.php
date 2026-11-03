<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\StatutContenu;
use App\Enums\UsageVariante;
use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Resources\CommentaireResource;
use App\Http\Resources\ContenuResource;
use App\Jobs\AnalyserCapture;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\DecisionModeration;
use App\Models\Signalement;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Validation\Rule;

/**
 * Lot 6 : la file et les décisions (E24, E25), pour les administrateurs seuls (Gate `moderer`).
 * Deux files : « À vérifier » (ce que l'analyse n'a pas su trancher) et « Signalements ».
 */
class ModerationController extends Controller
{
    /** GET moderation/file?file=a_verifier|signalements */
    public function file(Request $requete): JsonResponse
    {
        $file = $requete->validate(['file' => ['nullable', Rule::in(['a_verifier', 'signalements'])]])['file'] ?? 'a_verifier';
        $avec = ['auteur', 'lieu.ville.pays', 'capture.modele', 'variantes'];

        $ouverts = Signalement::where('statut', 'ouvert');
        $totaux = [
            'a_verifier' => Contenu::where('statut', StatutContenu::FileHumaine)->count(),
            'signalements' => (clone $ouverts)->where('cible_type', 'contenu')->distinct()->count('cible_id'),
            'commentaires_signales' => Commentaire::where('masque', false)->whereIn('id', (clone $ouverts)->where('cible_type', 'commentaire')->select('cible_id'))->count(),
        ];

        if ($file === 'a_verifier') {
            // Les plus anciens d'abord : personne n'attend trop longtemps.
            $dossiers = Contenu::where('statut', StatutContenu::FileHumaine)->with($avec)->oldest('updated_at')->limit(50)->get()
                ->map(fn (Contenu $c) => [
                    'contenu' => (new ContenuResource($c))->resolve($requete),
                    'raison' => $c->recours_le !== null ? 'Seconde vérification demandée par l’auteur. Motif du refus : '.$c->motif : $c->motif,
                    'recours' => $c->recours_le !== null,
                    'signalements' => 0,
                    'depuis' => $c->updated_at?->toIso8601String(),
                ]);
        } else {
            // Les plus signalés d'abord.
            $groupes = (clone $ouverts)->where('cible_type', 'contenu')
                ->selectRaw('cible_id, count(*) as n, min(created_at) as depuis')
                ->groupBy('cible_id')->orderByDesc('n')->limit(50)->get();
            $contenus = Contenu::whereIn('id', $groupes->pluck('cible_id'))->with($avec)->get()->keyBy('id');
            $motifs = Signalement::where('statut', 'ouvert')->where('cible_type', 'contenu')->whereIn('cible_id', $groupes->pluck('cible_id'))
                ->get(['cible_id', 'motif'])->groupBy('cible_id');
            $dossiers = $groupes->filter(fn ($g) => $contenus->has($g->cible_id))->values()->map(fn ($g) => [
                'contenu' => (new ContenuResource($contenus[$g->cible_id]))->resolve($requete),
                'raison' => ($motifs[$g->cible_id] ?? collect())->pluck('motif')->countBy()->sortDesc()->keys()->first(),
                'motifs' => ($motifs[$g->cible_id] ?? collect())->pluck('motif')->countBy()->all(),
                'signalements' => (int) $g->n,
                'depuis' => $g->depuis,
            ]);
            // Les commentaires signalés, à part.
            $idsCommentaires = (clone $ouverts)->where('cible_type', 'commentaire')->distinct()->pluck('cible_id');
            $commentaires = Commentaire::whereIn('id', $idsCommentaires)->where('masque', false)->with(['auteur', 'repondA', 'contenu:id,ulid,utilisateur_id'])->get();
        }

        return response()->json([
            'file' => $file,
            'totaux' => $totaux,
            'data' => $dossiers->values()->all(),
            'commentaires' => isset($commentaires) ? CommentaireResource::collection($commentaires)->resolve($requete) : [],
        ]);
    }

    /** POST moderation/contenus/{contenu}/decision {decision: publier|refuser, motif} */
    public function decider(Request $requete, Contenu $contenu): JsonResponse
    {
        $v = $requete->validate([
            'decision' => ['required', Rule::in(['publier', 'refuser'])],
            'motif' => ['required_if:decision,refuser', 'nullable', 'string', 'max:300'],
        ], ['motif.required_if' => 'Donnez le motif du refus : son auteur le lira.']);
        if (in_array($contenu->statut, [StatutContenu::Brouillon, StatutContenu::Analyse], true)) {
            throw new ErreurMetier(422, 'Ce contenu n’est pas encore complet.');
        }
        $auteur = Utilisateur::find($contenu->utilisateur_id);

        if ($v['decision'] === 'publier') {
            if ($contenu->statut !== StatutContenu::Publie) {
                // Les tailles d'image se font à partir des fichiers gardés pour la vérification.
                $contenu->update(['statut' => StatutContenu::Analyse, 'motif' => null]);
                AnalyserCapture::dispatch($contenu, true);
            }
        } else {
            $contenu->update(['statut' => StatutContenu::Refuse, 'motif' => $v['motif'], 'badge' => null]);
            Activite::a($auteur, new Activite('refusee', 'Votre publication a été retirée par l’équipe. Motif : :motif', null, $contenu, valeurs: ['motif' => $v['motif']]));
        }

        DecisionModeration::create(['contenu_id' => $contenu->id, 'moderateur_id' => $requete->user()->id, 'decision' => $v['decision'], 'motif' => $v['motif'] ?? null]);
        Signalement::where('cible_type', 'contenu')->where('cible_id', $contenu->id)->where('statut', 'ouvert')->update(['statut' => 'traite']);

        return response()->json(['statut' => $contenu->refresh()->statut->value, 'message' => $v['decision'] === 'publier' ? __('Publié.') : __('Refusé. L’auteur a été prévenu.')]);
    }

    /** POST moderation/commentaires/{commentaire}/masquer */
    public function masquer(Request $requete, Commentaire $commentaire): JsonResponse
    {
        $motif = $requete->validate(['motif' => ['nullable', 'string', 'max:300']])['motif'] ?? null;
        $commentaire->update(['masque' => true]);
        DecisionModeration::create(['commentaire_id' => $commentaire->id, 'moderateur_id' => $requete->user()->id, 'decision' => 'masquer', 'motif' => $motif]);
        Signalement::where('cible_type', 'commentaire')->where('cible_id', $commentaire->id)->where('statut', 'ouvert')->update(['statut' => 'traite']);

        return response()->json(['masque' => true]);
    }

    /** POST moderation/commentaires/{commentaire}/classer : les signalements ne tiennent pas, le commentaire reste. */
    public function classerCommentaire(Request $requete, Commentaire $commentaire): JsonResponse
    {
        $n = Signalement::where('cible_type', 'commentaire')->where('cible_id', $commentaire->id)->where('statut', 'ouvert')->update(['statut' => 'classe']);
        DecisionModeration::create(['commentaire_id' => $commentaire->id, 'moderateur_id' => $requete->user()->id, 'decision' => 'classer']);

        return response()->json(['classes' => $n]);
    }

    /** POST moderation/contenus/{contenu}/classer : les signalements ne tiennent pas, le contenu reste. */
    public function classer(Request $requete, Contenu $contenu): JsonResponse
    {
        $n = Signalement::where('cible_type', 'contenu')->where('cible_id', $contenu->id)->where('statut', 'ouvert')->update(['statut' => 'classe']);
        DecisionModeration::create(['contenu_id' => $contenu->id, 'moderateur_id' => $requete->user()->id, 'decision' => 'classer']);

        return response()->json(['classes' => $n]);
    }

    /**
     * GET moderation/a-etiqueter : les publications en ligne dont personne n'a encore lu l'image
     * (publiées avant la lecture des étiquettes). Le téléphone de l'équipe les lit, 30 à la fois.
     */
    public function aEtiqueter(): JsonResponse
    {
        $contenus = Contenu::publies()->whereNull('etiquete_le')->with('variantes')->orderByDesc('id')->limit(30)->get();

        return response()->json(['data' => $contenus->map(function (Contenu $c) {
            $v = $c->variantes->firstWhere('usage', UsageVariante::Ecran) ?? $c->variantes->firstWhere('usage', UsageVariante::Affiche)
                ?? $c->variantes->firstWhere('usage', UsageVariante::Petite);

            return $v === null ? null : ['id' => $c->ulid, 'image' => $v->url()];
        })->filter()->values()]);
    }

    /** PUT moderation/contenus/{contenu}/etiquettes : ce que le téléphone de l'équipe a vu sur la photo. */
    public function etiqueter(Request $requete, Contenu $contenu): Response
    {
        $v = $requete->validate([
            'etiquettes' => ['present', 'array', 'max:30'],
            'etiquettes.*.nom' => ['required', 'string', 'max:60'],
            'etiquettes.*.confiance' => ['required', 'numeric', 'between:0,1'],
        ]);
        $contenu->etiqueter($v['etiquettes']);

        return response()->noContent();
    }
}
