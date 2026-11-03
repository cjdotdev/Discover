<?php

namespace App\Console\Commands;

use App\Support\VersionPhp;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Lancée à chaque déploiement (ARCHITECTURE.md, section 10) : elle échoue, et arrête le
 * déploiement, si PHP est une version vulnérable à php2shell.
 */
#[Signature('usw:verifier-php {--version-php= : La version à vérifier, celle du serveur par défaut}')]
#[Description('Vérifie que PHP corrige php2shell (8.5.12, 8.4.27, 8.3.36 ou 8.2.35 au minimum)')]
class VerifierPhp extends Command
{
    public function handle(): int
    {
        $version = $this->option('version-php') ?: PHP_VERSION;

        if (VersionPhp::estCorrigee($version)) {
            $this->info("PHP {$version} : corrigé.");

            return self::SUCCESS;
        }

        $this->error("PHP {$version} est vulnérable à php2shell. Minimums : ".implode(', ', VersionPhp::CORRIGEES).'.');

        return self::FAILURE;
    }
}
