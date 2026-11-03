<?php

namespace Tests\Feature;

use Tests\TestCase;

/** Les langues à télécharger : les africaines d'abord, par ordre alphabétique, puis le paquet. */
class LanguesTest extends TestCase
{
    private array $fichiers = [];

    protected function tearDown(): void
    {
        foreach ($this->fichiers as $f) {
            @unlink($f);
        }
        parent::tearDown();
    }

    private function paquet(string $code, array $j): void
    {
        $f = resource_path("langues/{$code}.json");
        file_put_contents($f, json_encode(['code' => $code, 'version' => 1, 'textes' => ['Enregistrer' => "x-{$code}"]] + $j, JSON_UNESCAPED_UNICODE));
        $this->fichiers[] = $f;
    }

    public function test_la_liste_puis_le_paquet(): void
    {
        $this->paquet('zx', ['nom' => 'Español', 'africaine' => false]);
        $this->paquet('zy', ['nom' => 'Yorùbá', 'africaine' => true, 'a_relire' => true]);
        $this->paquet('zz', ['nom' => 'Èʋegbe', 'africaine' => true]);

        $l = collect($this->getJson('/api/v1/langues')->assertOk()->json('data'))->whereIn('code', ['zx', 'zy', 'zz'])->values();
        $this->assertSame(['zz', 'zy', 'zx'], $l->pluck('code')->all());
        $this->assertTrue($l[1]['a_relire']);

        $r = $this->get('/api/v1/langues/zy')->assertOk()->assertJsonPath('textes.Enregistrer', 'x-zy');
        $this->get('/api/v1/langues/zy', ['If-None-Match' => $r->headers->get('ETag')])->assertStatus(304);
        $this->getJson('/api/v1/langues/inconnue')->assertNotFound();
        $this->getJson('/api/v1/langues/qq')->assertNotFound();
    }
}
