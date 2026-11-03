<?php

namespace App\Services\Compte;

use App\Exceptions\ErreurMetier;
use App\Mail\CodeParEmail;
use App\Models\CodeEmail;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Throwable;

/**
 * Les codes à 6 chiffres, seule façon d'entrer avec un e-mail : hachés en base, valables
 * 10 minutes, 5 essais au plus. Chaque code est lié à un défi, un secret remis au seul téléphone
 * qui l'a demandé : sans lui, on ne peut pas essayer ce code (ni épuiser ses essais). Une même
 * adresse garde 3 codes en cours au plus ; un nouveau défi n'annule pas ceux des autres.
 */
class GestionnaireCodes
{
    public const DUREE_MINUTES = 10;

    public const ESSAIS = 5;

    public const BUT = 'connexion';

    /** Confirmer la nouvelle adresse d'un compte : ce code n'ouvre aucun compte. */
    public const CHANGEMENT = 'changement';

    /** Les codes en cours d'une même adresse, au plus. */
    public const EN_COURS = 3;

    public static function hacherDefi(string $defi): string
    {
        return hash('sha256', $defi.'|'.config('app.key'));
    }

    /**
     * Un code part à cette adresse. Renvoie son défi. `$defi` : celui que le téléphone a déjà
     * (renvoyer un code) ; son code précédent ne vaut plus.
     */
    public function envoyer(string $email, string $but = self::BUT, ?string $defi = null): string
    {
        $defi = $defi !== null && preg_match('/^[A-Za-z0-9]{40}$/', $defi) ? $defi : Str::random(40);
        $actifs = CodeEmail::where('email', $email)->where('but', $but)->whereNull('utilise_le');
        (clone $actifs)->where('defi_hache', self::hacherDefi($defi))->update(['utilise_le' => now()]);
        // Les plus anciens au-delà de 3 ne valent plus.
        $garder = (clone $actifs)->where('defi_hache', '!=', self::hacherDefi($defi))->latest('id')->limit(self::EN_COURS - 1)->pluck('id');
        (clone $actifs)->whereNotIn('id', $garder)->update(['utilise_le' => now()]);

        $code = (string) random_int(100000, 999999);
        CodeEmail::create([
            'email' => $email,
            'but' => $but,
            'code_hache' => Hash::make($code),
            'defi_hache' => self::hacherDefi($defi),
            'expire_le' => now()->addMinutes(self::DUREE_MINUTES),
        ]);

        try {
            Mail::to($email)->send(new CodeParEmail($code, $but));
        } catch (Throwable $e) {
            // Resend injoignable ou refusant l'envoi : on le dit, plutôt qu'un code qui n'arrive jamais.
            Log::error('Le code n’a pas pu partir.', ['email' => $email, 'erreur' => $e->getMessage()]);
            throw new ErreurMetier(503, 'Le code n’a pas pu partir. Réessayez dans un instant.');
        }

        return $defi;
    }

    /**
     * Vérifie un code. Renvoie le code reconnu, ou une raison d'échec : `faux` (avec les essais
     * restants), `epuise` ou `expire`.
     *
     * @return array{0: ?CodeEmail, 1: ?string, 2: int}
     */
    public function verifier(string $email, string $code, string $but, string $defi): array
    {
        $enCours = CodeEmail::where('email', $email)->where('but', $but)->whereNull('utilise_le')
            ->where('defi_hache', self::hacherDefi($defi))->latest('id')->first();
        if ($enCours === null || $enCours->expire_le->isPast()) {
            return [null, 'expire', 0];
        }
        // L'essai se compte avant la vérification, en une seule requête : des essais en parallèle
        // ne dépassent pas les 5.
        if (CodeEmail::whereKey($enCours->id)->where('essais', '<', self::ESSAIS)->increment('essais') === 0) {
            return [null, 'epuise', 0];
        }
        if (! Hash::check($code, $enCours->code_hache)) {
            $essais = (int) CodeEmail::whereKey($enCours->id)->value('essais');

            return [null, $essais >= self::ESSAIS ? 'epuise' : 'faux', self::ESSAIS - $essais];
        }

        return [$enCours, null, 0];
    }
}
