<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\Badge;
use App\Http\Controllers\Controller;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use App\Support\Medias;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Collection;

/** Lot 7 : le centre des notifications (E17). Elles partent d'elles-mêmes après 60 jours. */
class NotificationController extends Controller
{
    /** GET notifications?curseur=… : les plus récentes d'abord, 30 par page, et le nombre de non lues. */
    public function index(Request $requete): JsonResponse
    {
        $u = $requete->user();
        $page = $u->notifications()->orderByDesc('created_at')->orderByDesc('id')->cursorPaginate(30, cursorName: 'curseur');
        // Qui a agi, tel qu'il est aujourd'hui : sa photo de profil et son nom ont pu changer depuis
        // (l'ancienne photo est effacée, son adresse gardée dans la notification ne mène plus à rien).
        $acteurs = $this->acteurs($page->getCollection());
        // La publication aussi, telle qu'elle est : son badge, sa photo, son lieu (ou partie).
        $contenus = $this->contenus($page->getCollection());

        return response()->json([
            'data' => $page->getCollection()->map(function (DatabaseNotification $n) use ($acteurs, $contenus) {
                $contenu = $this->contenuActuel($n->data['contenu'] ?? null, $contenus);

                return [
                    'id' => $n->id,
                    ...$n->data,
                    // Une publication en ligne : son texte suit son badge d'aujourd'hui (les plus
                    // anciennes disaient « vérifiée » même pour des informations déclarées).
                    ...$this->texteActuel($n->data, $contenu),
                    'acteur' => $this->acteurActuel($n->data['acteur'] ?? null, $acteurs),
                    'contenu' => $contenu,
                    'lue' => $n->read_at !== null,
                    'cree_le' => $n->created_at?->toIso8601String(),
                ];
            })->all(),
            'non_lues' => $u->unreadNotifications()->count(),
            'meta' => ['next_cursor' => $page->nextCursor()?->encode()],
        ]);
    }

    /**
     * Les membres nommés par ces notifications, par leur identifiant (les plus récentes le gardent)
     * ou, pour les plus anciennes, par leur nom d'utilisateur d'alors.
     *
     * @param  Collection<int, DatabaseNotification>  $notifications
     * @return array{ids: array<string, Utilisateur>, noms: array<string, Utilisateur>}
     */
    private function acteurs(Collection $notifications): array
    {
        $donnees = $notifications->map(fn (DatabaseNotification $n) => $n->data['acteur'] ?? null)->filter();
        $ids = $donnees->pluck('id')->filter()->unique()->values()->all();
        $noms = $donnees->whereNull('id')->pluck('nom_utilisateur')->filter()->unique()->values()->all();
        if ($ids === [] && $noms === []) {
            return ['ids' => [], 'noms' => []];
        }
        $membres = Utilisateur::query()
            ->where(fn ($q) => $q->whereIn('ulid', $ids)->orWhereIn('nom_utilisateur', $noms))
            ->get(['id', 'ulid', 'nom_utilisateur', 'nom_affiche', 'avatar']);

        return ['ids' => $membres->keyBy('ulid')->all(), 'noms' => $membres->keyBy('nom_utilisateur')->all()];
    }

    /** L'acteur d'une notification, à jour ; tel qu'il était si son compte n'existe plus. */
    private function acteurActuel(?array $acteur, array $acteurs): ?array
    {
        if ($acteur === null) {
            return null;
        }
        $m = isset($acteur['id']) ? ($acteurs['ids'][$acteur['id']] ?? null) : ($acteurs['noms'][$acteur['nom_utilisateur'] ?? ''] ?? null);
        if ($m === null) {
            return $acteur;
        }

        return [
            'id' => $m->ulid,
            'nom_utilisateur' => $m->nom_utilisateur,
            'nom_affiche' => $m->nom_affiche,
            'avatar' => $m->avatar ? Medias::public()->url($m->avatar) : null,
        ];
    }

    /**
     * Les publications nommées par ces notifications, par leur identifiant public.
     *
     * @param  Collection<int, DatabaseNotification>  $notifications
     * @return array<string, Contenu>
     */
    private function contenus(Collection $notifications): array
    {
        $ulids = $notifications->map(fn (DatabaseNotification $n) => $n->data['contenu']['id'] ?? null)->filter()->unique()->values()->all();

        return $ulids === [] ? [] : Contenu::whereIn('ulid', $ulids)->with(['lieu:id,slug', 'variantes'])->get()->keyBy('ulid')->all();
    }

    /** La publication d'une notification, à jour ; nulle si elle a été supprimée depuis. */
    private function contenuActuel(?array $contenu, array $contenus): ?array
    {
        $c = $contenu === null ? null : ($contenus[$contenu['id'] ?? ''] ?? null);
        if ($c === null) {
            return null;
        }
        $photo = $c->variantes->first(fn ($v) => in_array($v->usage->value, ['480', 'affiche'], true));

        return [
            'id' => $c->ulid,
            'type' => $c->type->value,
            'badge' => $c->badge?->value,
            'lieu' => $c->lieu?->slug,
            'photo' => $photo ? $photo->url() : null,
        ];
    }

    /**
     * Une publication en ligne : son texte suit son badge d'aujourd'hui (les plus anciennes disaient
     * « vérifiée » même pour des informations déclarées) ; supprimée depuis, la notification le dit.
     *
     * @param  array<string, mixed>  $donnees
     * @return array{texte?: string}
     */
    private function texteActuel(array $donnees, ?array $contenu): array
    {
        if (($donnees['genre'] ?? null) !== 'publiee' || ! isset($donnees['contenu'])) {
            return [];
        }

        return ['texte' => $contenu === null ? 'Cette publication a été supprimée.' : Activite::textePubliee(Badge::tryFrom((string) $contenu['badge']))];
    }

    /** DELETE notifications/{id} : retirer une notification de la liste. */
    public function supprimer(Request $requete, string $id): JsonResponse
    {
        $requete->user()->notifications()->whereKey($id)->delete();

        return response()->json(['non_lues' => $requete->user()->unreadNotifications()->count()]);
    }

    /** POST notifications/lues {ids?} : celles-ci, ou toutes. */
    public function lues(Request $requete): JsonResponse
    {
        $ids = $requete->validate(['ids' => ['nullable', 'array', 'max:100'], 'ids.*' => ['string', 'max:40']])['ids'] ?? null;
        $q = $requete->user()->unreadNotifications();
        if ($ids !== null) {
            $q->whereIn('id', $ids);
        }
        $q->update(['read_at' => now()]);

        return response()->json(['non_lues' => $requete->user()->unreadNotifications()->count()]);
    }
}
