<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\StatutEnvoi;
use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Requests\Compte\ChangerAvatar;
use App\Http\Requests\Compte\ModifierProfil;
use App\Http\Requests\Exploration\PageDeContenus;
use App\Http\Resources\ContenuResource;
use App\Http\Resources\UtilisateurResource;
use App\Mail\AdresseChangee;
use App\Models\Abonnement;
use App\Models\AppareilPush;
use App\Models\Blocage;
use App\Models\Collection;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\Envoi;
use App\Models\Reaction;
use App\Models\Signalement;
use App\Models\Utilisateur;
use App\Services\Compte\Comptes;
use App\Services\Compte\GestionnaireCodes;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Throwable;

/** Le membre connecté : son profil, sa photo, la suppression de son compte. Il n'agit que sur lui-même. */
class MoiController extends Controller
{
    /** GET moi */
    public function afficher(Request $requete): UtilisateurResource
    {
        return new UtilisateurResource($requete->user());
    }

    /** PATCH moi : seuls les champs envoyés changent ; « profil_complete » clôt l'E36. */
    /** GET auth/nom-libre?nom= : ce nom d'utilisateur est-il libre ? Le mien compte comme libre. */
    public function nomLibre(Request $requete): JsonResponse
    {
        $nom = mb_strtolower(ltrim(trim((string) $requete->query('nom')), '@'));
        if (strlen($nom) < 3 || strlen($nom) > 30) {
            return response()->json(['libre' => false, 'message' => __('Le nom d’utilisateur doit faire entre 3 et 30 caractères.')]);
        }
        if (! preg_match('/^[a-z0-9._]+$/', $nom)) {
            return response()->json(['libre' => false, 'message' => __('Le nom d’utilisateur ne peut contenir que des lettres minuscules, des chiffres, des points et des tirets bas.')]);
        }
        $pris = Utilisateur::where('nom_utilisateur', $nom)->whereKeyNot($requete->user()->id)->exists();

        return response()->json(['libre' => ! $pris, 'message' => $pris ? __('Ce nom d’utilisateur est déjà pris.') : null]);
    }

    public function modifier(ModifierProfil $requete): UtilisateurResource
    {
        $u = $requete->user();
        $donnees = $requete->safe()->except('profil_complete');
        $u->fill($donnees);
        if ($requete->boolean('profil_complete')) {
            $u->profil_complete_le ??= now();
        }
        $u->save();

        return new UtilisateurResource($u);
    }

    /** POST moi/avatar */
    public function avatar(ChangerAvatar $requete, Comptes $comptes): UtilisateurResource
    {
        try {
            $comptes->changerAvatar($requete->user(), $requete->file('avatar'));
        } catch (RuntimeException) {
            throw ValidationException::withMessages(['avatar' => 'Cette image n’a pas pu être lue. Essayez une autre photo.']);
        }

        return new UtilisateurResource($requete->user()->refresh());
    }

    /** DELETE moi/avatar : plus de photo de profil, les initiales partout. */
    public function retirerAvatar(Request $requete, Comptes $comptes): UtilisateurResource
    {
        $comptes->retirerAvatar($requete->user());

        return new UtilisateurResource($requete->user()->refresh());
    }

    /**
     * GET moi/contenus : tout ce que j'ai publié ou tenté de publier (E18), avec son statut
     * (en vérification, à compléter, refusé et pourquoi), les plus récents d'abord.
     */
    public function contenus(PageDeContenus $requete): AnonymousResourceCollection
    {
        $u = $requete->user();
        // Mon lifestyle a sa page (moi/lifestyle).
        $page = $u->contenus()->where('portee', '!=', 'lifestyle')
            ->when($requete->validated('type'), fn ($q, $type) => $q->where('type', $type))
            ->with(['lieu.ville.pays', 'capture.modele', 'variantes'])
            ->orderByDesc('created_at')->orderByDesc('id')
            ->cursorPaginate(20, cursorName: 'curseur');
        $page->getCollection()->each->setRelation('auteur', $u);

        return ContenuResource::collection($page);
    }

    /** GET moi/envois : mes envois en cours (E26), à reprendre après une coupure. */
    public function envois(Request $requete): JsonResponse
    {
        $envois = Envoi::where('utilisateur_id', $requete->user()->id)
            ->where('statut', StatutEnvoi::EnCours)
            ->with('contenu')
            ->latest('derniere_activite')
            ->get();

        return response()->json(['data' => $envois->map(fn ($e) => [
            'id' => $e->ulid,
            'contenu' => $e->contenu->ulid,
            'role' => $e->role->value,
            'taille' => $e->taille,
            'recu' => $e->recu,
            'derniere_activite' => $e->derniere_activite?->toIso8601String(),
        ])]);
    }

    /**
     * DELETE moi : le compte est effacé dans 30 jours (usw:purger-comptes), avec ses
     * données. Tous ses jetons tombent ; se reconnecter avant annule la suppression.
     */
    /**
     * POST moi/email : changer d'adresse, étape 1. L'application a d'abord demandé le verrou du
     * téléphone (empreinte, code) ; ici, un code part sur la nouvelle adresse pour prouver qu'elle
     * est à vous. Un compte lié à Google garde l'adresse de Google.
     */
    public function demanderEmail(Request $requete, GestionnaireCodes $codes): JsonResponse
    {
        $u = $requete->user();
        if ($u->google_sub !== null) {
            throw new ErreurMetier(409, 'Votre compte est lié à Google : son adresse est celle de votre compte Google.');
        }
        $email = mb_strtolower(trim((string) $requete->input('email')));
        $requete->merge(['email' => $email]);
        $requete->validate(['email' => ['required', 'string', 'email:rfc', 'max:190']]);
        if ($email === $u->email) {
            throw ValidationException::withMessages(['email' => 'C’est déjà votre adresse.']);
        }
        // Prise par un autre compte : rien ne part, mais la réponse ne le dit pas (confirmer refusera).
        $defi = Utilisateur::where('email', $email)->whereKeyNot($u->id)->doesntExist()
            ? $codes->envoyer($email, GestionnaireCodes::CHANGEMENT)
            : Str::random(40);
        Cache::put('email:nouvelle:'.$u->id, ['email' => $email, 'defi' => $defi], now()->addMinutes(GestionnaireCodes::DUREE_MINUTES + 5));

        return response()->json(['message' => __('Un code à 6 chiffres a été envoyé à :email.', ['email' => $email])]);
    }

    /** POST moi/email/confirmer : le code juste, et l'adresse change ; l'ancienne est prévenue. */
    public function confirmerEmail(Request $requete, GestionnaireCodes $codes): UtilisateurResource
    {
        $v = $requete->validate(['code' => ['required', 'string', 'regex:/^\d{6}$/']], ['code.regex' => 'Le code a 6 chiffres.']);
        $u = $requete->user();
        $attente = Cache::get('email:nouvelle:'.$u->id);
        if (! is_array($attente)) {
            throw ValidationException::withMessages(['code' => 'Ce code a expiré : demandez-en un nouveau.']);
        }
        $email = $attente['email'];
        [$code, $echec, $reste] = $codes->verifier($email, $v['code'], GestionnaireCodes::CHANGEMENT, $attente['defi']);
        if ($code === null) {
            throw ValidationException::withMessages(['code' => match ($echec) {
                'faux' => $reste === 1 ? 'Code incorrect. Encore 1 essai.' : "Code incorrect. Encore {$reste} essais.",
                'epuise' => 'Trop d’essais : demandez un nouveau code.',
                default => 'Ce code a expiré : demandez-en un nouveau.',
            }]);
        }
        if (Utilisateur::where('email', $email)->whereKeyNot($u->id)->exists()) {
            throw ValidationException::withMessages(['code' => 'Cette adresse est déjà celle d’un autre compte.']);
        }
        $code->update(['utilise_le' => now()]);
        $ancienne = $u->email;
        $u->forceFill(['email' => $email, 'email_verifie_le' => now()])->save();
        $actuel = $u->currentAccessToken();
        $u->tokens()->when($actuel instanceof Model, fn ($q) => $q->whereKeyNot($actuel->getKey()))->delete();
        Cache::forget('email:nouvelle:'.$u->id);
        try {
            Mail::to($ancienne)->send(new AdresseChangee($email));
        } catch (Throwable $e) {
            Log::warning('L’alerte de changement d’adresse n’est pas partie.', ['utilisateur' => $u->id, 'erreur' => $e->getMessage()]);
        }

        return new UtilisateurResource($u);
    }

    /**
     * GET moi/donnees : tout ce que Discover garde sur ce compte, en JSON (le droit d'accès et de
     * portabilité). Les codes de connexion et les jetons n'y sont pas : ils ne servent qu'à entrer.
     */
    public function donnees(Request $requete): JsonResponse
    {
        $u = $requete->user();
        $date = fn ($d) => $d?->toIso8601String();
        $contenus = $u->contenus()->with(['lieu', 'capture.modele', 'variantes'])->latest('id')->get();

        return response()->json([
            'exporte_le' => now()->toIso8601String(),
            'compte' => [
                'email' => $u->email,
                'nom_affiche' => $u->nom_affiche,
                'nom_utilisateur' => $u->nom_utilisateur,
                'bio' => $u->bio,
                'site' => $u->site,
                'pays' => $u->pays,
                'ville' => $u->ville,
                'types_aimes' => $u->types_aimes,
                'connexion' => $u->google_sub !== null ? 'google' : 'email',
                'cree_le' => $date($u->created_at),
            ],
            'publications' => $contenus->map(fn (Contenu $c) => [
                'id' => $c->ulid,
                'type' => $c->type->value,
                'statut' => $c->statut->value,
                'titre' => $c->titre,
                'legende' => $c->legende,
                'lieu' => $c->lieu?->nom,
                'publie_le' => $date($c->publie_le),
                'telephone' => $c->capture?->modele?->nom,
                'prise_le' => $date($c->capture?->prise_le),
                'latitude' => $c->capture?->latitude,
                'longitude' => $c->capture?->longitude,
                'fichiers' => $c->variantes->map(fn ($v) => $v->url())->values(),
            ])->values(),
            'commentaires' => Commentaire::where('utilisateur_id', $u->id)->with('contenu:id,ulid')->latest('id')->get()
                ->map(fn (Commentaire $m) => ['publication' => $m->contenu?->ulid, 'texte' => $m->texte, 'le' => $date($m->created_at)])->values(),
            'reactions' => Reaction::where('utilisateur_id', $u->id)->with('contenu:id,ulid')->get()
                ->map(fn (Reaction $r) => ['publication' => $r->contenu?->ulid, 'type' => $r->type, 'le' => $date($r->created_at)])->values(),
            'collections' => $u->collections()->get()->map(fn (Collection $c) => [
                'nom' => $c->nom,
                'secrete' => $c->secrete,
                'publications' => DB::table('enregistrements')->join('contenus', 'contenus.id', '=', 'enregistrements.contenu_id')
                    ->where('enregistrements.collection_id', $c->id)->pluck('contenus.ulid'),
            ])->values(),
            'abonnements' => Utilisateur::whereIn('id', Abonnement::where('abonne_id', $u->id)->select('createur_id'))->pluck('nom_utilisateur'),
            'abonnes' => Abonnement::where('createur_id', $u->id)->count(),
            'comptes_bloques' => Utilisateur::whereIn('id', Blocage::where('bloqueur_id', $u->id)->select('bloque_id'))->pluck('nom_utilisateur'),
            'signalements' => Signalement::where('utilisateur_id', $u->id)->get(['cible_type', 'motif', 'statut', 'created_at'])
                ->map(fn (Signalement $s) => ['cible' => $s->cible_type, 'motif' => $s->motif, 'statut' => $s->statut, 'le' => $date($s->created_at)])->values(),
        ], 200, ['Cache-Control' => 'no-store']);
    }

    public function supprimer(Request $requete): JsonResponse
    {
        $u = $requete->user();
        $u->suppression_demandee_le ??= now();
        $u->save();
        $u->tokens()->delete();
        $u->appareilsPush()->delete();
        $le = $u->suppression_demandee_le->copy()->addDays(Utilisateur::JOURS_AVANT_SUPPRESSION);

        return response()->json([
            'message' => __('Votre compte sera supprimé le :date. Reconnectez-vous avant cette date pour le conserver.', ['date' => $le->locale(app()->getLocale())->isoFormat('D MMMM YYYY')]),
            'supprime_le' => $le->toIso8601String(),
        ]);
    }

    /**
     * PUT moi/push : ce téléphone reçoit les notifications (le jeton Firebase), avec les choix
     * des réglages. Rappelé à chaque changement de réglage ou de jeton.
     */
    public function push(Request $requete): JsonResponse
    {
        $v = $requete->validate([
            'jeton' => ['required', 'string', 'max:512'],
            'preferences' => ['nullable', 'array'],
            'preferences.*' => ['boolean'],
            'pause_jusqu_a' => ['nullable', 'date'],
        ]);
        AppareilPush::updateOrCreate(['jeton' => $v['jeton']], [
            'utilisateur_id' => $requete->user()->id,
            'jeton_acces_id' => ($jeton = $requete->user()->currentAccessToken()) instanceof Model ? $jeton->getKey() : null,
            'preferences' => $v['preferences'] ?? null,
            'pause_jusqu_a' => $v['pause_jusqu_a'] ?? null,
        ]);

        return response()->json(['message' => __('Ce téléphone reçoit les notifications.')]);
    }

    /** DELETE moi/push : ce téléphone ne reçoit plus rien (notifications coupées). */
    public function oublierPush(Request $requete): JsonResponse
    {
        $v = $requete->validate(['jeton' => ['required', 'string', 'max:512']]);
        $requete->user()->appareilsPush()->where('jeton', $v['jeton'])->delete();

        return response()->json(['message' => __('Ce téléphone ne reçoit plus les notifications.')]);
    }
}
