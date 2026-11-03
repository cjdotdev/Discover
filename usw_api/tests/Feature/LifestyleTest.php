<?php

namespace Tests\Feature;

use App\Models\Blocage;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Utilisateur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Le lifestyle : l'album de vie de chaque membre, hors de l'accueil, visible seulement s'il le veut. */
class LifestyleTest extends TestCase
{
    use RefreshDatabase;

    private Utilisateur $ola;

    private Contenu $repas;

    protected function setUp(): void
    {
        parent::setUp();
        $lieu = Lieu::create(['slug' => 'cotonou', 'nom' => 'Cotonou', 'type' => 'Villes', 'latitude' => 6.36, 'longitude' => 2.42]);
        $this->ola = Utilisateur::factory()->create(['nom_utilisateur' => 'ola', 'nom_affiche' => 'Ola']);
        $this->repas = Contenu::factory()->complet()->create(['utilisateur_id' => $this->ola->id, 'lieu_id' => $lieu->id, 'portee' => 'lifestyle', 'legende' => 'Le repas de dimanche']);
        Contenu::factory()->complet()->create(['utilisateur_id' => $this->ola->id, 'lieu_id' => $lieu->id, 'legende' => 'La plage']);
    }

    public function test_hors_de_l_accueil_des_lieux_de_la_recherche_et_du_profil(): void
    {
        $this->assertSame(['La plage'], array_column($this->getJson('/api/v1/lieux/cotonou/contenus')->json('data'), 'legende'));
        $this->assertSame(['La plage'], array_column($this->getJson('/api/v1/utilisateurs/ola/contenus')->json('data'), 'legende'));
        $this->getJson('/api/v1/recherche?q=dimanche')->assertJsonCount(0, 'contenus');
        $this->getJson('/api/v1/utilisateurs/ola')->assertJsonPath('data.compteurs.contenus', 1);
    }

    public function test_cache_tant_que_le_membre_ne_l_a_pas_rendu_visible(): void
    {
        $kofi = Utilisateur::factory()->create();
        $this->getJson('/api/v1/lifestyles')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/utilisateurs/ola/lifestyle')->assertNotFound();
        $this->actingAs($kofi)->getJson("/api/v1/contenus/{$this->repas->ulid}")->assertNotFound();
        $this->getJson('/api/v1/utilisateurs/ola')->assertJsonPath('data.compteurs.lifestyle', 0);
        // Lui le voit toujours.
        $this->app['auth']->forgetGuards();
        $this->actingAs($this->ola)->getJson('/api/v1/utilisateurs/ola/lifestyle')->assertOk()->assertJsonCount(1, 'data');
        $this->actingAs($this->ola)->getJson("/api/v1/contenus/{$this->repas->ulid}")->assertOk();
    }

    public function test_visible_il_se_trouve_dans_la_recherche_avec_sa_pile(): void
    {
        $this->actingAs($this->ola)->putJson('/api/v1/moi/lifestyle', ['visible' => true])->assertOk()->assertJsonPath('visible', true);
        $this->app['auth']->forgetGuards();

        $this->getJson('/api/v1/lifestyles')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.auteur.nom_utilisateur', 'ola')
            ->assertJsonPath('data.0.nombre', 1)
            ->assertJsonPath('data.0.photos.0.id', $this->repas->ulid);
        $this->getJson('/api/v1/lifestyles?q=ol')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/lifestyles?q=kofi')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/utilisateurs/ola/lifestyle')->assertOk()->assertJsonPath('data.0.legende', 'Le repas de dimanche');
        $this->getJson("/api/v1/contenus/{$this->repas->ulid}")->assertOk();
        $this->getJson('/api/v1/utilisateurs/ola')->assertJsonPath('data.compteurs.lifestyle', 1);
    }

    public function test_un_membre_bloque_ne_voit_pas_mon_lifestyle(): void
    {
        $this->ola->forceFill(['lifestyle_visible' => true])->save();
        $kofi = Utilisateur::factory()->create();
        Blocage::create(['bloqueur_id' => $this->ola->id, 'bloque_id' => $kofi->id]);

        $this->actingAs($kofi)->getJson('/api/v1/lifestyles')->assertJsonCount(0, 'data');
        $this->actingAs($kofi)->getJson('/api/v1/utilisateurs/ola/lifestyle')->assertNotFound();
    }
}
