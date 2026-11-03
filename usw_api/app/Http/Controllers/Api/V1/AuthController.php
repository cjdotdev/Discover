<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ErreurMetier;
use App\Http\Controllers\Controller;
use App\Http\Requests\Compte\ConnexionGoogle;
use App\Http\Requests\Compte\DemanderCode;
use App\Http\Requests\Compte\VerifierCode;
use App\Http\Resources\UtilisateurResource;
use App\Models\AppareilPush;
use App\Models\Utilisateur;
use App\Services\Compte\Comptes;
use App\Services\Compte\GestionnaireCodes;
use App\Services\Compte\VerificateurJetonGoogle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Entrer dans Discover, sans mot de passe : l'e-mail, puis le code à 6 chiffres qu'on y reçoit
 * (le même parcours pour un nouveau compte et pour un compte existant) ; ou Google. La réponse
 * à l'envoi du code est toujours la même : elle ne dit pas si une adresse est inscrite.
 */
class AuthController extends Controller
{
    public function __construct(private Comptes $comptes, private GestionnaireCodes $codes) {}

    /** POST auth/code/envoyer : un code part à cette adresse (l'ancien ne vaut plus). */
    public function envoyer(DemanderCode $requete): JsonResponse
    {
        $email = $requete->validated('email');
        $defi = $this->codes->envoyer($email, GestionnaireCodes::BUT, $requete->validated('defi'));

        // Le défi reste sur ce téléphone : seul lui pourra essayer le code.
        return response()->json(['message' => __('Un code à 6 chiffres a été envoyé à :email.', ['email' => $email]), 'defi' => $defi]);
    }

    /** POST auth/code : le code juste ouvre le compte, ou le crée (201) s'il n'existait pas. */
    public function code(VerifierCode $requete): JsonResponse
    {
        $email = $requete->validated('email');
        [$code, $echec, $reste] = $this->codes->verifier($email, $requete->validated('code'), GestionnaireCodes::BUT, $requete->validated('defi'));
        if ($code === null) {
            throw ValidationException::withMessages(['code' => match ($echec) {
                'faux' => $reste === 1 ? 'Code incorrect. Encore 1 essai.' : "Code incorrect. Encore {$reste} essais.",
                'epuise' => 'Trop d’essais : demandez un nouveau code.',
                default => 'Ce code a expiré : demandez-en un nouveau.',
            }]);
        }
        $code->update(['utilise_le' => now()]);

        $u = Utilisateur::where('email', $email)->first();
        $nouveau = $u === null;
        $u ??= new Utilisateur(['email' => $email, 'fournisseur' => 'email']);
        $u->email_verifie_le ??= now();
        $u->nom_utilisateur ??= $this->comptes->nomLibre('membre'.random_int(10000, 99999));
        $u->save();

        return $this->connecte($u, $requete->validated('appareil'), $nouveau ? 201 : 200);
    }

    /** POST auth/google : le compte est retrouvé (par Google ou par l'e-mail) ou créé. */
    public function google(ConnexionGoogle $requete, VerificateurJetonGoogle $verificateur): JsonResponse
    {
        $g = $verificateur->verifier($requete->validated('jeton'));
        if ($g === null) {
            throw ValidationException::withMessages(['jeton' => 'La connexion avec Google n’a pas abouti. Réessayez.']);
        }
        $u = Utilisateur::where('google_sub', $g['sub'])->first() ?? Utilisateur::where('email', $g['email'])->first();
        $nouveau = $u === null;
        $u ??= new Utilisateur(['email' => $g['email'], 'fournisseur' => 'google']);
        $u->google_sub = $g['sub'];
        $u->email_verifie_le ??= now();
        $u->nom_affiche ??= $g['nom'];
        $u->nom_utilisateur ??= $this->comptes->nomLibre(Str::slug((string) $g['nom'], '.') ?: 'membre'.random_int(10000, 99999));
        $u->save();

        return $this->connecte($u, $requete->validated('appareil'), $nouveau ? 201 : 200);
    }

    /** POST auth/deconnexion : seul le jeton de ce téléphone disparaît. */
    public function deconnexion(Request $requete): JsonResponse
    {
        $jeton = $requete->user()->currentAccessToken();
        if ($jeton !== null) {
            AppareilPush::where('jeton_acces_id', $jeton->getKey())->delete();
            $jeton->delete();
        }

        return response()->json(['message' => __('Vous êtes déconnecté.')]);
    }

    private function connecte(Utilisateur $u, ?string $appareil, int $statut = 200): JsonResponse
    {
        if ($u->estSuspendu()) {
            throw new ErreurMetier(403, 'Ce compte est suspendu par l’équipe de Discover.');
        }
        // Revenu avant les 30 jours : la suppression demandée est annulée.
        if ($u->suppression_demandee_le !== null) {
            $u->suppression_demandee_le = null;
            $u->save();
        }

        return response()->json([
            'jeton' => $this->comptes->jeton($u, $appareil),
            'nouveau' => $statut === 201,
            'utilisateur' => new UtilisateurResource($u),
        ], $statut);
    }
}
