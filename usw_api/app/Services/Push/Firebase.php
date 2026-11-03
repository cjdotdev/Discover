<?php

namespace App\Services\Push;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * L'envoi des notifications par Firebase Cloud Messaging (API HTTP v1). Le compte de service
 * vient de FIREBASE_IDENTIFIANTS (son JSON, en clair ou en base64) : sans lui, rien ne part et
 * les notifications restent dans l'application.
 */
class Firebase
{
    /** Le jeton du téléphone n'existe plus (appli désinstallée, données effacées) : à oublier. */
    public const JETON_INVALIDE = 'invalide';

    public const ENVOYE = 'envoye';

    public const ECHEC = 'echec';

    private ?array $compte = null;

    public function configure(): bool
    {
        return $this->compte() !== null;
    }

    /**
     * @param  array<string, string>  $donnees  ce que l'application lit quand on touche la notification
     */
    public function envoyer(string $jeton, string $titre, string $corps, array $donnees = [], ?string $image = null): string
    {
        $compte = $this->compte() ?? throw new RuntimeException('Firebase n’est pas configuré.');
        $notification = array_filter(['title' => $titre, 'body' => $corps, 'image' => $image]);
        $reponse = Http::withToken($this->jetonAcces($compte))
            ->timeout(15)
            ->post("https://fcm.googleapis.com/v1/projects/{$compte['project_id']}/messages:send", [
                'message' => [
                    'token' => $jeton,
                    'notification' => $notification,
                    'data' => array_map('strval', $donnees),
                    'android' => [
                        'priority' => 'high',
                        'notification' => [
                            'channel_id' => 'activite',
                            'icon' => 'ic_notification',
                            'color' => '#5D7CFB',
                        ],
                    ],
                ],
            ]);

        if ($reponse->successful()) {
            return self::ENVOYE;
        }
        $code = $reponse->json('error.details.0.errorCode') ?? $reponse->json('error.status');
        if ($reponse->status() === 404 || in_array($code, ['UNREGISTERED', 'INVALID_ARGUMENT'], true)) {
            return self::JETON_INVALIDE;
        }
        if ($reponse->status() === 401) {
            Cache::forget('firebase.acces');
        }

        return self::ECHEC;
    }

    /** Le jeton OAuth du compte de service, gardé 50 minutes (Google le donne pour une heure). */
    private function jetonAcces(array $compte): string
    {
        return Cache::remember('firebase.acces', 3000, function () use ($compte) {
            $maintenant = time();
            $morceaux = [
                $this->base64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'])),
                $this->base64url(json_encode([
                    'iss' => $compte['client_email'],
                    'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                    'aud' => $compte['token_uri'] ?? 'https://oauth2.googleapis.com/token',
                    'iat' => $maintenant,
                    'exp' => $maintenant + 3600,
                ])),
            ];
            if (! openssl_sign(implode('.', $morceaux), $signature, $compte['private_key'], OPENSSL_ALGO_SHA256)) {
                throw new RuntimeException('La clé du compte de service Firebase est illisible.');
            }
            $morceaux[] = $this->base64url($signature);

            return Http::asForm()->timeout(15)->post($compte['token_uri'] ?? 'https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => implode('.', $morceaux),
            ])->throw()->json('access_token');
        });
    }

    private function compte(): ?array
    {
        if ($this->compte !== null) {
            return $this->compte;
        }
        $brut = trim((string) config('discover.firebase'));
        if ($brut === '') {
            return null;
        }
        $json = str_starts_with($brut, '{') ? $brut : base64_decode($brut, true);
        $compte = $json === false ? null : json_decode($json, true);
        if (! is_array($compte) || ! isset($compte['project_id'], $compte['client_email'], $compte['private_key'])) {
            return null;
        }

        return $this->compte = $compte;
    }

    private function base64url(string $s): string
    {
        return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
    }
}
