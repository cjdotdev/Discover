<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\StatutContenu;
use App\Http\Controllers\Controller;
use App\Http\Resources\ContenuResource;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Reaction;
use App\Models\Signalement;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use App\Support\Medias;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * « Gérer Discover » : l'application de l'équipe dans l'application (middleware `equipe`).
 * Le tableau de bord (chiffres et courbes), les membres (recherche, filtres, fiche), la
 * suspension et les messages de l'équipe, les signalements de membres.
 */
class AdministrationController extends Controller
{
    /** Un membre est en ligne s'il a agi dans les 5 dernières minutes. */
    private const EN_LIGNE_MINUTES = 5;

    /** GET admin/acces : la porte (404 pour tout autre compte, par le middleware). */
    public function acces(Request $requete): JsonResponse
    {
        return response()->json(['ok' => true, 'nom' => $requete->user()->nom_affiche]);
    }

    /** GET admin/tableau?jours=7|30|90 : les chiffres du moment et les courbes de la période. */
    public function tableau(Request $requete): JsonResponse
    {
        $jours = (int) ($requete->validate(['jours' => ['nullable', Rule::in(['7', '30', '90'])]])['jours'] ?? 30);
        $debut = CarbonImmutable::today()->subDays($jours - 1);
        $avant = $debut->subDays($jours);
        $maintenant = now();

        $actifsDepuis = fn (CarbonImmutable $d) => DB::table('activites_jour')->where('jour', '>=', $d->toDateString())->distinct()->count('utilisateur_id');
        $publies = Contenu::publies();
        $periode = fn (Builder $q, string $col = 'created_at') => [
            'periode' => (clone $q)->where($col, '>=', $debut)->count(),
            'precedente' => (clone $q)->whereBetween($col, [$avant, $debut])->count(),
        ];

        return response()->json([
            'jours' => $jours,
            'maintenant' => [
                'en_ligne' => Utilisateur::where('derniere_activite_le', '>=', $maintenant->copy()->subMinutes(self::EN_LIGNE_MINUTES))->count(),
                'aujourdhui' => $actifsDepuis(CarbonImmutable::today()),
                'semaine' => $actifsDepuis(CarbonImmutable::today()->subDays(6)),
                'mois' => $actifsDepuis(CarbonImmutable::today()->subDays(29)),
                'membres' => Utilisateur::count(),
                'suspendus' => Utilisateur::whereNotNull('suspendu_le')->count(),
                'publications' => (clone $publies)->where('type', 'photo')->count(),
                'reels' => (clone $publies)->where('type', 'reel')->count(),
                'a_verifier' => Contenu::where('statut', StatutContenu::FileHumaine)->count(),
                'signalements' => Signalement::where('statut', 'ouvert')->count(),
            ],
            'periode' => [
                'inscriptions' => $periode(Utilisateur::query()),
                'publications' => $periode(Contenu::publies(), 'publie_le'),
                'reactions' => $periode(Reaction::query()),
                'commentaires' => $periode(Commentaire::query()),
                'signalements' => $periode(Signalement::query()),
            ],
            'courbes' => [
                'dates' => collect(range(0, $jours - 1))->map(fn ($i) => $debut->addDays($i)->toDateString())->all(),
                'actifs' => $this->parJour(DB::table('activites_jour')->selectRaw('jour, count(*) as n')->where('jour', '>=', $debut->toDateString())->groupBy('jour'), $debut, $jours),
                'inscriptions' => $this->parJour($this->compteParJour(Utilisateur::query(), 'created_at', $debut), $debut, $jours),
                'publications' => $this->parJour($this->compteParJour(Contenu::publies(), 'publie_le', $debut), $debut, $jours),
                'reactions' => $this->parJour($this->compteParJour(Reaction::query(), 'created_at', $debut), $debut, $jours),
                'commentaires' => $this->parJour($this->compteParJour(Commentaire::query(), 'created_at', $debut), $debut, $jours),
            ],
            'lieux' => $this->lieuxEnVue($debut),
            'createurs' => $this->createursEnVue($debut),
        ]);
    }

    /** GET admin/membres?q=&filtre=&tri=&page= : la recherche, les filtres, le tri. */
    public function membres(Request $requete): JsonResponse
    {
        $v = $requete->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'filtre' => ['nullable', Rule::in(['tous', 'en_ligne', 'aujourdhui', 'semaine', 'mois', 'nouveaux', 'suspendus', 'signales', 'inactifs'])],
            'tri' => ['nullable', Rule::in(['recents', 'actifs', 'publications', 'signalements', 'nom'])],
        ]);
        $q = Utilisateur::query()->select('utilisateurs.*')
            ->withCount(['contenus as publications' => fn ($c) => $c->where('statut', StatutContenu::Publie)])
            ->addSelect(['signalements' => $this->signalementsRecus()]);

        // Chaque mot doit se trouver dans le nom, le nom d'utilisateur, l'adresse ou la ville
        // (sans accents) ; « @nom » cherche le début d'un nom d'utilisateur.
        foreach (preg_split('/\s+/', trim((string) ($v['q'] ?? ''))) ?: [] as $mot) {
            if ($mot === '') {
                continue;
            }
            str_starts_with($mot, '@')
                ? $q->where('nom_utilisateur', 'like', mb_strtolower(substr($mot, 1)).'%')
                : $q->where('recherche', 'like', '%'.Utilisateur::normaliser($mot).'%');
        }

        $aujourdhui = CarbonImmutable::today();
        match ($v['filtre'] ?? 'tous') {
            'en_ligne' => $q->where('derniere_activite_le', '>=', now()->subMinutes(self::EN_LIGNE_MINUTES)),
            'aujourdhui' => $q->where('derniere_activite_le', '>=', $aujourdhui),
            'semaine' => $q->where('derniere_activite_le', '>=', $aujourdhui->subDays(6)),
            'mois' => $q->where('derniere_activite_le', '>=', $aujourdhui->subDays(29)),
            'inactifs' => $q->where(fn ($w) => $w->whereNull('derniere_activite_le')->orWhere('derniere_activite_le', '<', $aujourdhui->subDays(29))),
            'nouveaux' => $q->where('created_at', '>=', $aujourdhui->subDays(6)),
            'suspendus' => $q->whereNotNull('suspendu_le'),
            'signales' => $q->where($this->signalementsRecus(), '>', 0),
            default => null,
        };
        match ($v['tri'] ?? 'recents') {
            'actifs' => $q->orderByRaw('derniere_activite_le is null')->orderByDesc('derniere_activite_le'),
            'publications' => $q->orderByDesc('publications'),
            'signalements' => $q->orderByDesc('signalements'),
            'nom' => $q->orderBy('nom_utilisateur'),
            default => $q->orderByDesc('created_at'),
        };
        $page = $q->orderByDesc('utilisateurs.id')->paginate(30);

        return response()->json([
            'data' => collect($page->items())->map(fn (Utilisateur $u) => $this->membre($u))->all(),
            'total' => $page->total(),
            'page' => $page->currentPage(),
            'derniere_page' => $page->lastPage(),
        ]);
    }

    /** GET admin/membres/{nom} : la fiche d'un membre, tout son parcours. */
    public function fiche(Request $requete, string $nom): JsonResponse
    {
        $u = $this->trouver($nom);
        $debut = CarbonImmutable::today()->subDays(29);
        $contenus = $u->contenus()->with(['lieu.ville.pays', 'capture.modele', 'variantes'])->latest()->limit(12)->get();
        $contenus->each->setRelation('auteur', $u);
        $idsContenus = Contenu::where('utilisateur_id', $u->id)->pluck('id');

        $signalements = Signalement::where(fn ($w) => $w->where(fn ($a) => $a->where('cible_type', 'utilisateur')->where('cible_id', $u->id))
            ->orWhere(fn ($b) => $b->where('cible_type', 'contenu')->whereIn('cible_id', $idsContenus)))
            ->latest()->limit(20)->get();

        return response()->json([
            'membre' => $this->membre($u, detail: true),
            'compteurs' => [
                'publications' => Contenu::where('utilisateur_id', $u->id)->where('statut', StatutContenu::Publie)->where('type', 'photo')->count(),
                'reels' => Contenu::where('utilisateur_id', $u->id)->where('statut', StatutContenu::Publie)->where('type', 'reel')->count(),
                'refusees' => Contenu::where('utilisateur_id', $u->id)->where('statut', StatutContenu::Refuse)->count(),
                'reactions_recues' => Reaction::whereIn('contenu_id', $idsContenus)->count(),
                'reactions_donnees' => Reaction::where('utilisateur_id', $u->id)->count(),
                'commentaires' => Commentaire::where('utilisateur_id', $u->id)->count(),
                'abonnes' => (int) $u->nombre_abonnes,
                'abonnements' => (int) $u->nombre_abonnements,
                'collections' => $u->collections()->count(),
                'signalements_recus' => Signalement::where('statut', 'ouvert')->where(fn ($w) => $w->where(fn ($a) => $a->where('cible_type', 'utilisateur')->where('cible_id', $u->id))
                    ->orWhere(fn ($b) => $b->where('cible_type', 'contenu')->whereIn('cible_id', $idsContenus)))->count(),
                'signalements_faits' => Signalement::where('utilisateur_id', $u->id)->count(),
                'jours_actifs' => DB::table('activites_jour')->where('utilisateur_id', $u->id)->where('jour', '>=', $debut->toDateString())->count(),
            ],
            'courbes' => [
                'dates' => collect(range(0, 29))->map(fn ($i) => $debut->addDays($i)->toDateString())->all(),
                'actif' => $this->parJour(DB::table('activites_jour')->selectRaw('jour, count(*) as n')->where('utilisateur_id', $u->id)->where('jour', '>=', $debut->toDateString())->groupBy('jour'), $debut, 30),
                'reactions_recues' => $this->parJour($this->compteParJour(Reaction::whereIn('contenu_id', $idsContenus), 'created_at', $debut), $debut, 30),
            ],
            'contenus' => ContenuResource::collection($contenus)->resolve($requete),
            'contenus_statuts' => $contenus->mapWithKeys(fn (Contenu $c) => [$c->ulid => $c->statut->value])->all(),
            'signalements' => $signalements->map(fn (Signalement $s) => [
                'motif' => $s->motif,
                'precision' => $s->precision,
                'cible' => $s->cible_type,
                'statut' => $s->statut,
                'le' => $s->created_at?->toIso8601String(),
            ])->all(),
            'appareils' => $u->tokens()->latest('last_used_at')->limit(10)->get()->map(fn ($t) => [
                'nom' => $t->name,
                'depuis' => $t->created_at?->toIso8601String(),
                'dernier_usage' => $t->last_used_at?->toIso8601String(),
            ])->all(),
            'messages' => $u->notifications()->where('type', 'equipe')->latest()->limit(10)->get()->map(fn ($n) => [
                'ton' => $n->data['ton'] ?? 'info',
                'texte' => $n->data['texte'] ?? '',
                'le' => $n->created_at?->toIso8601String(),
                'lu' => $n->read_at !== null,
            ])->all(),
        ]);
    }

    /** POST admin/membres/{nom}/suspension {motif} : il ne peut plus entrer, ses publications se cachent. */
    public function suspendre(Request $requete, string $nom): JsonResponse
    {
        $motif = $requete->validate(['motif' => ['required', 'string', 'max:300']], ['motif.required' => 'Donnez le motif : il est gardé avec la suspension.'])['motif'];
        $u = $this->trouver($nom);
        if ($u->id === $requete->user()->id) {
            return response()->json(['message' => __('Vous ne pouvez pas suspendre votre propre compte.')], 422);
        }
        $u->forceFill(['suspendu_le' => now(), 'motif_suspension' => $motif])->save();
        $u->tokens()->delete();
        $u->appareilsPush()->delete();
        Signalement::where('cible_type', 'utilisateur')->where('cible_id', $u->id)->where('statut', 'ouvert')->update(['statut' => 'traite']);

        return response()->json(['message' => __('@:nom est suspendu.', ['nom' => $u->nom_utilisateur]), 'membre' => $this->membre($u->refresh(), detail: true)]);
    }

    /** DELETE admin/membres/{nom}/suspension : il peut revenir. */
    public function reactiver(string $nom): JsonResponse
    {
        $u = $this->trouver($nom);
        $u->forceFill(['suspendu_le' => null, 'motif_suspension' => null])->save();

        return response()->json(['message' => __('@:nom peut de nouveau utiliser Discover.', ['nom' => $u->nom_utilisateur]), 'membre' => $this->membre($u->refresh(), detail: true)]);
    }

    /** POST admin/membres/{nom}/message {ton, texte} : une notification signée « L'équipe de Discover ». */
    public function message(Request $requete, string $nom): JsonResponse
    {
        $v = $requete->validate([
            'ton' => ['required', Rule::in(['felicitations', 'avertissement', 'info'])],
            'texte' => ['required', 'string', 'min:3', 'max:500'],
        ], ['texte.required' => 'Écrivez le message.']);
        $u = $this->trouver($nom);
        $u->notify(new Activite('equipe', $v['texte'], ton: $v['ton']));

        return response()->json(['message' => __('Message envoyé à @:nom.', ['nom' => $u->nom_utilisateur])], 201);
    }

    /** GET admin/signalements/membres : les membres signalés, les plus signalés d'abord. */
    public function membresSignales(): JsonResponse
    {
        $groupes = Signalement::where('statut', 'ouvert')->where('cible_type', 'utilisateur')
            ->selectRaw('cible_id, count(*) as n, min(created_at) as depuis')->groupBy('cible_id')->orderByDesc('n')->limit(50)->get();
        $membres = Utilisateur::whereIn('id', $groupes->pluck('cible_id'))->get()->keyBy('id');
        $motifs = Signalement::where('statut', 'ouvert')->where('cible_type', 'utilisateur')->whereIn('cible_id', $groupes->pluck('cible_id'))
            ->get(['cible_id', 'motif'])->groupBy('cible_id');

        return response()->json(['data' => $groupes->filter(fn ($g) => $membres->has($g->cible_id))->values()->map(fn ($g) => [
            'membre' => $this->membre($membres[$g->cible_id]),
            'signalements' => (int) $g->n,
            'motifs' => ($motifs[$g->cible_id] ?? collect())->pluck('motif')->countBy()->sortDesc()->all(),
            'depuis' => $g->depuis,
        ])->all()]);
    }

    /** POST admin/signalements/membres/{nom}/classer : les signalements ne tiennent pas. */
    public function classerMembre(string $nom): JsonResponse
    {
        $u = $this->trouver($nom);
        $n = Signalement::where('cible_type', 'utilisateur')->where('cible_id', $u->id)->where('statut', 'ouvert')->update(['statut' => 'classe']);

        return response()->json(['classes' => $n]);
    }

    // ------------------------------------------------------------------ outils

    private function trouver(string $nom): Utilisateur
    {
        return Utilisateur::where('nom_utilisateur', ltrim($nom, '@'))->orWhere('ulid', $nom)->firstOrFail();
    }

    /** @return array<string, mixed> */
    private function membre(Utilisateur $u, bool $detail = false): array
    {
        $enLigne = $u->derniere_activite_le !== null && $u->derniere_activite_le->gte(now()->subMinutes(self::EN_LIGNE_MINUTES));

        return [
            'id' => $u->ulid,
            'nom_utilisateur' => $u->nom_utilisateur,
            'nom_affiche' => $u->nom_affiche,
            'email' => $u->email,
            'avatar' => $u->avatar ? Medias::public()->url($u->avatar) : null,
            'ville' => trim(implode(', ', array_filter([$u->ville, $u->pays]))),
            'fournisseur' => $u->fournisseur,
            'inscrit_le' => $u->created_at?->toIso8601String(),
            'derniere_activite' => $u->derniere_activite_le?->toIso8601String(),
            'en_ligne' => $enLigne,
            'suspendu' => $u->suspendu_le !== null,
            'publications' => (int) ($u->publications ?? 0),
            'signalements' => (int) ($u->signalements ?? 0),
            'equipe' => $u->estAdmin(),
        ] + ($detail ? [
            'bio' => $u->bio,
            'suspendu_le' => $u->suspendu_le?->toIso8601String(),
            'motif_suspension' => $u->motif_suspension,
            'profil_complete' => $u->profil_complete_le !== null,
            'suppression_demandee_le' => $u->suppression_demandee_le?->toIso8601String(),
        ] : []);
    }

    /** Les signalements ouverts contre un membre ou ses publications (sous-requête). */
    private function signalementsRecus(): Builder
    {
        return Signalement::selectRaw('count(*)')->where('statut', 'ouvert')->where(fn ($w) => $w
            ->where(fn ($a) => $a->where('cible_type', 'utilisateur')->whereColumn('cible_id', 'utilisateurs.id'))
            ->orWhere(fn ($b) => $b->where('cible_type', 'contenu')->whereIn('cible_id', Contenu::select('id')->whereColumn('contenus.utilisateur_id', 'utilisateurs.id'))));
    }

    private function compteParJour(Builder $q, string $col, CarbonImmutable $debut): Builder
    {
        return $q->where($col, '>=', $debut)->selectRaw("date($col) as jour, count(*) as n")->groupBy('jour')->reorder();
    }

    /**
     * Une valeur par jour, de $debut à aujourd'hui (0 les jours sans rien).
     *
     * @return list<int>
     */
    private function parJour(Builder|\Illuminate\Database\Query\Builder $q, CarbonImmutable $debut, int $jours): array
    {
        $n = $q->pluck('n', 'jour')->mapWithKeys(fn ($v, $k) => [substr((string) $k, 0, 10) => (int) $v]);

        return collect(range(0, $jours - 1))->map(fn ($i) => $n[$debut->addDays($i)->toDateString()] ?? 0)->all();
    }

    /** Les lieux qui ont reçu le plus de publications sur la période. */
    private function lieuxEnVue(CarbonImmutable $debut): array
    {
        $top = Contenu::publies()->where('publie_le', '>=', $debut)->whereNotNull('lieu_id')
            ->selectRaw('lieu_id, count(*) as n')->groupBy('lieu_id')->orderByDesc('n')->limit(5)->get();
        $lieux = Lieu::whereIn('id', $top->pluck('lieu_id'))->get()->keyBy('id');

        return $top->filter(fn ($t) => $lieux->has($t->lieu_id))->values()
            ->map(fn ($t) => ['id' => $lieux[$t->lieu_id]->slug, 'nom' => $lieux[$t->lieu_id]->nom, 'n' => (int) $t->n])->all();
    }

    /** Les créateurs dont les publications ont reçu le plus de réactions sur la période. */
    private function createursEnVue(CarbonImmutable $debut): array
    {
        $top = Reaction::where('reactions.created_at', '>=', $debut)->join('contenus', 'contenus.id', '=', 'reactions.contenu_id')
            ->selectRaw('contenus.utilisateur_id as u, count(*) as n')->groupBy('contenus.utilisateur_id')->orderByDesc('n')->limit(5)->get();
        $membres = Utilisateur::whereIn('id', $top->pluck('u'))->get()->keyBy('id');

        return $top->filter(fn ($t) => $membres->has($t->u))->values()->map(fn ($t) => [
            'nom_utilisateur' => $membres[$t->u]->nom_utilisateur,
            'nom_affiche' => $membres[$t->u]->nom_affiche,
            'avatar' => $membres[$t->u]->avatar ? Medias::public()->url($membres[$t->u]->avatar) : null,
            'n' => (int) $t->n,
        ])->all();
    }
}
