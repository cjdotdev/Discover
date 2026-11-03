<?php

namespace Tests\Unit;

use App\Support\VersionPhp;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class VersionPhpTest extends TestCase
{
    /** @return array<string, array{string, bool}> */
    public static function versions(): array
    {
        return [
            '8.5.12 corrigée' => ['8.5.12', true],
            '8.5.13 corrigée' => ['8.5.13', true],
            '8.5.11 vulnérable' => ['8.5.11', false],
            '8.4.27 corrigée' => ['8.4.27', true],
            '8.4.26 vulnérable' => ['8.4.26', false],
            '8.3.36 corrigée' => ['8.3.36', true],
            '8.2.34 vulnérable' => ['8.2.34', false],
            '8.1 plus suivie' => ['8.1.40', false],
            '8.6 plus récente' => ['8.6.0', true],
            'suffixe accepté' => ['8.5.12-dev', true],
            'illisible' => ['huit', false],
        ];
    }

    #[DataProvider('versions')]
    public function test_reconnait_les_versions_corrigees(string $version, bool $attendu): void
    {
        $this->assertSame($attendu, VersionPhp::estCorrigee($version));
    }
}
