<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\TypeContenu;
use App\Http\Controllers\Controller;
use App\Http\Resources\AuteurResource;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Models\Vue;
use App\Support\Spectateur;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * POST vues : ce que l'application a vu, par paquets. Une vue compte une fois par personne, par
 * publication et par jour, à partir de 2 secondes pour une photo et de 3 pour un reel ; un reel
 * regardé jusqu'au bout compte aussi comme « vue complète ». Ses propres publications ne
 * comptent pas. Ouvert sans compte : un téléphone se reconnaît à son en-tête X-Appareil.
 * La réponse donne le nombre de vues à jour de chaque publication du paquet : l'écran suit
 * (une durée de 0 ne compte pas, et sert à redemander ce nombre).
 */
class VueController extends Controller
{
    private const MINIMUM_MS = ['photo' => 2000, 'reel' => 3000];

    public function enregistrer(Request $requete): JsonResponse
    {
        $v = $requete->validate([
            'vues' => ['required', 'array', 'min:1', 'max:50'],
            'vues.*.contenu' => ['required', 'string', 'max:40'],
            'vues.*.duree_ms' => ['required', 'integer', 'min:0', 'max:86400000'],
            'vues.*.complete' => ['sometimes', 'boolean'],
        ]);
        $moi = $requete->user('sanctum');
        $spectateur = Spectateur::de($requete);
        $jour = today()->toDateString();

        // Plusieurs fois la même publication dans un paquet : la plus longue, et « complète » si l'une l'est.
        $parUlid = collect($v['vues'])->groupBy('contenu')->map(fn ($g) => [
            'duree_ms' => (int) $g->max('duree_ms'),
            'complete' => $g->contains(fn ($x) => ! empty($x['complete'])),
        ]);
        $contenus = Contenu::publies()->whereIn('ulid', $parUlid->keys())->get(['id', 'ulid', 'type', 'utilisateur_id']);

        foreach ($contenus as $c) {
            if ($moi !== null && $c->utilisateur_id === $moi->id) {
                continue;
            }
            $d = $parUlid[$c->ulid];
            $reel = $c->type === TypeContenu::Reel;
            if ($d['duree_ms'] < self::MINIMUM_MS[$reel ? 'reel' : 'photo']) {
                continue;
            }
            $complete = $reel && $d['complete'];
            DB::transaction(function () use ($c, $spectateur, $jour, $d, $complete) {
                $nouvelle = Vue::query()->insertOrIgnore([
                    'contenu_id' => $c->id, 'spectateur' => $spectateur, 'jour' => $jour,
                    'duree_ms' => $d['duree_ms'], 'complete' => $complete,
                    'created_at' => now(), 'updated_at' => now(),
                ]) > 0;
                $q = Contenu::whereKey($c->id)->toBase();
                if ($nouvelle) {
                    $complete
                        ? $q->update(['nombre_vues' => DB::raw('nombre_vues + 1'), 'nombre_vues_completes' => DB::raw('nombre_vues_completes + 1')])
                        : $q->increment('nombre_vues');

                    return;
                }
                // Déjà vue aujourd'hui : elle peut devenir complète (une seule fois).
                if ($complete && Vue::where(['contenu_id' => $c->id, 'spectateur' => $spectateur, 'jour' => $jour, 'complete' => false])
                    ->update(['complete' => true, 'duree_ms' => $d['duree_ms'], 'updated_at' => now()]) > 0) {
                    $q->increment('nombre_vues_completes');
                }
            });
        }

        return response()->json([
            'vues' => (object) Contenu::whereIn('id', $contenus->pluck('id'))->pluck('nombre_vues', 'ulid')->map(fn ($n) => (int) $n)->all(),
        ]);
    }

    /**
     * GET contenus/{contenu}/spectateurs : qui a vu ma publication, les plus récents d'abord.
     * Seul son auteur le voit (une autre personne reçoit 404). Les visiteurs sans compte ne
     * sont pas nommés : seulement leur nombre.
     */
    public function spectateurs(Request $requete, Contenu $contenu): JsonResponse
    {
        abort_unless($requete->user()->id === $contenu->utilisateur_id, 404);
        $vues = Vue::where('contenu_id', $contenu->id);
        $membres = (clone $vues)->where('spectateur', 'like', 'u:%')
            ->selectRaw('spectateur, max(updated_at) as vu_le')->groupBy('spectateur')
            ->orderByDesc('vu_le')->limit(200)->get();
        $comptes = Utilisateur::whereIn('id', $membres->map(fn ($v) => (int) substr($v->spectateur, 2)))->get()->keyBy('id');

        return response()->json([
            'total' => (int) $contenu->nombre_vues,
            'sans_compte' => (clone $vues)->where('spectateur', 'like', 'a:%')->distinct()->count('spectateur'),
            'data' => $membres->map(function ($v) use ($comptes, $requete) {
                $compte = $comptes->get((int) substr($v->spectateur, 2));

                return $compte === null ? null : [
                    'membre' => (new AuteurResource($compte))->resolve($requete),
                    'vu_le' => Carbon::parse($v->vu_le)->toIso8601String(),
                ];
            })->filter()->values()->all(),
        ]);
    }

    /**
     * POST contenus/{contenu}/pas-interesse : elle ne revient plus dans « Pour toi », et son
     * créateur y passe moins souvent (Recommandation). Rien n'est dit à son auteur.
     */
    public function pasInteresse(Request $requete, Contenu $contenu): Response
    {
        abort_unless($contenu->estVisible(), 404);
        DB::table('desinterets')->insertOrIgnore([
            'spectateur' => Spectateur::de($requete), 'contenu_id' => $contenu->id, 'auteur_id' => $contenu->utilisateur_id,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return response()->noContent();
    }
}
