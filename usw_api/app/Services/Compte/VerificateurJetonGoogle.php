<?php

namespace App\Services\Compte;

/**
 * Vérifie le jeton d'identité que l'application a obtenu de Google (signature, émetteur, audience,
 * expiration). Les tests le remplacent par un double (ARCHITECTURE.md, section 4).
 */
interface VerificateurJetonGoogle
{
    /**
     * @return array{sub: string, email: string, nom: ?string, photo: ?string}|null nul si le jeton n'est pas valable
     */
    public function verifier(string $jeton): ?array;
}
