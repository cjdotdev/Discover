<?php

namespace Tests\Feature;

use Tests\TestCase;

class VerifierPhpTest extends TestCase
{
    public function test_une_version_corrigee_laisse_passer_le_deploiement(): void
    {
        $this->artisan('usw:verifier-php', ['--version-php' => '8.5.12'])
            ->expectsOutput('PHP 8.5.12 : corrigé.')
            ->assertSuccessful();
    }

    public function test_une_version_vulnerable_arrete_le_deploiement(): void
    {
        $this->artisan('usw:verifier-php', ['--version-php' => '8.5.11'])->assertFailed();
    }

    public function test_le_php_du_poste_est_corrige(): void
    {
        $this->artisan('usw:verifier-php')->assertSuccessful();
    }
}
