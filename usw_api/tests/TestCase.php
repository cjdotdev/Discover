<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        // Symfony prête à chaque requête de test un « Accept-Language: en-us » : les tests
        // parlent français, la langue de l'application. Un test peut en demander une autre.
        // (Une variable du serveur, pas un en-tête : $this->call() la reçoit aussi.)
        $this->withServerVariables(['HTTP_ACCEPT_LANGUAGE' => 'fr']);
    }
}
