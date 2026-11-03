<?php

namespace Tests\Feature;

use App\Models\Utilisateur;
use App\Notifications\Activite;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Le serveur parle la langue de l'application : réponses, et notifications dans la langue du destinataire. */
class LangueServeurTest extends TestCase
{
    use RefreshDatabase;

    private string $fichier;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fichier = resource_path('langues/zz.json');
        file_put_contents($this->fichier, json_encode(['code' => 'zz', 'nom' => 'Zz', 'version' => 1, 'textes' => [
            ':nom a aimé votre publication.' => 'ZZ :nom aime.',
        ]], JSON_UNESCAPED_UNICODE));
    }

    protected function tearDown(): void
    {
        @unlink($this->fichier);
        parent::tearDown();
    }

    public function test_la_langue_de_l_application_est_gardee_puis_les_notifications_la_suivent(): void
    {
        $moi = Utilisateur::factory()->create();
        $ami = Utilisateur::factory()->create(['nom_affiche' => 'Ama']);

        $this->actingAs($moi)->getJson('/api/v1/moi', ['Accept-Language' => 'zz-ZZ,fr;q=0.8'])->assertOk();
        $this->assertSame('zz', $moi->refresh()->langue);
        // Une langue inconnue : le français.
        $this->actingAs($ami)->getJson('/api/v1/moi', ['Accept-Language' => 'xx'])->assertOk();
        $this->assertSame('fr', $ami->refresh()->langue);

        Activite::a($moi, new Activite('reaction', ':nom a aimé votre publication.', $ami, valeurs: ['nom' => 'Ama']));
        Activite::a($ami, new Activite('reaction', ':nom a aimé votre publication.', $moi, valeurs: ['nom' => 'Kofi']));
        $this->assertSame('ZZ Ama aime.', $moi->notifications()->first()->data['texte']);
        $this->assertSame('Kofi a aimé votre publication.', $ami->notifications()->first()->data['texte']);
    }
}
