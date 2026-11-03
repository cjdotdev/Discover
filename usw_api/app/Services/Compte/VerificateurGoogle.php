<?php

namespace App\Services\Compte;

use Illuminate\Support\Facades\Http;

/**
 * La vérification par Google lui-même (point « tokeninfo ») : Google contrôle la signature et
 * l'expiration ; on contrôle l'émetteur, l'audience (nos identifiants clients) et l'e-mail vérifié.
 */
class VerificateurGoogle implements VerificateurJetonGoogle
{
    /** @param  list<string>  $audiences  les identifiants clients OAuth de Discover (Android, web) */
    public function __construct(private array $audiences) {}

    public function verifier(string $jeton): ?array
    {
        if ($this->audiences === []) {
            return null;
        }
        $reponse = Http::timeout(8)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $jeton]);
        if (! $reponse->ok()) {
            return null;
        }
        $c = $reponse->json();
        $emetteurOk = in_array($c['iss'] ?? '', ['accounts.google.com', 'https://accounts.google.com'], true);
        $audienceOk = in_array($c['aud'] ?? '', $this->audiences, true);
        $emailOk = ($c['email_verified'] ?? 'false') === 'true' || ($c['email_verified'] ?? false) === true;
        $valable = (int) ($c['exp'] ?? 0) > time();
        if (! $emetteurOk || ! $audienceOk || ! $emailOk || ! $valable || empty($c['sub']) || empty($c['email'])) {
            return null;
        }

        return ['sub' => (string) $c['sub'], 'email' => mb_strtolower($c['email']), 'nom' => $c['name'] ?? null, 'photo' => $c['picture'] ?? null];
    }
}
