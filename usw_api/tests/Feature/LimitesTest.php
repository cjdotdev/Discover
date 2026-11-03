<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LimitesTest extends TestCase
{
    use RefreshDatabase;

    public function test_trop_d_essais_de_code_repond_429_avec_un_message(): void
    {
        // Comme en production : sans le détail des erreurs.
        config(['app.debug' => false]);
        // 20 essais par heure pour une adresse depuis une IP (une IP seule en permet 60 par minute :
        // elle est souvent partagee).
        for ($i = 0; $i < 20; $i++) {
            $this->postJson('/api/v1/auth/code', ['email' => 'a@exemple.bj', 'code' => '000000'])->assertStatus(422);
        }
        $r = $this->postJson('/api/v1/auth/code', ['email' => 'a@exemple.bj', 'code' => '000000']);
        $r->assertStatus(429)->assertJsonStructure(['message'])->assertHeader('Retry-After');
    }
}
