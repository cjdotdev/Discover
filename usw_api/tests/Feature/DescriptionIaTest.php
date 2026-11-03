<?php

namespace Tests\Feature;

use App\Models\Contenu;
use App\Models\Lieu;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** L'IA décrit ce qu'on voit sur les publications : la recherche trouve par le contenu, pas seulement la légende. */
class DescriptionIaTest extends TestCase
{
    use RefreshDatabase;

    private Lieu $lieu;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.ia.url' => 'https://ia.test']);
        $this->lieu = Lieu::create(['slug' => 'cotonou', 'nom' => 'Cotonou', 'type' => 'Villes', 'latitude' => 6.36, 'longitude' => 2.42]);
    }

    public function test_chercher_nourriture_trouve_le_plat_de_chez_maman(): void
    {
        $plat = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'legende' => 'Chez maman']);
        $commerce = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'legende' => 'Le marché']);
        Http::fake(fn ($r) => str_contains((string) $r['image'], $plat->ulid)
            ? Http::response(['description' => 'Un plat de riz et de poisson frit sur une table.', 'mots' => ['riz', 'poisson', 'plat', 'nourriture', 'intérieur']])
            : Http::response(['description' => 'Des étals de commerçants sous des parasols.', 'mots' => ['commerce', 'marché', 'personne']]));

        $this->artisan('usw:decrire')->assertSuccessful();

        $this->assertSame('Un plat de riz et de poisson frit sur une table.', $plat->refresh()->description_ia);
        $this->assertNotNull($plat->decrit_le);
        $this->getJson('/api/v1/recherche?q=nourriture')->assertOk()->assertJsonCount(1, 'contenus')->assertJsonPath('contenus.0.id', $plat->ulid);
        // Au pluriel, et sans accent.
        $this->getJson('/api/v1/recherche?q=Poissons')->assertJsonCount(1, 'contenus');
        $this->getJson('/api/v1/recherche?q=interieur')->assertJsonCount(1, 'contenus');
        // Des mots entiers : « mer » ne trouve pas « commerce ».
        $this->getJson('/api/v1/recherche?q=mer')->assertJsonCount(0, 'contenus');
        $this->getJson('/api/v1/recherche?q=marche')->assertJsonCount(1, 'contenus')->assertJsonPath('contenus.0.id', $commerce->ulid);
    }

    public function test_une_ia_indisponible_redemande_au_passage_suivant(): void
    {
        $c = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        Http::fake(['*' => Http::sequence()->push(['erreur' => 'ia indisponible'], 503)->push(['erreur' => 'image refusee'], 422)]);
        $this->artisan('usw:decrire')->assertSuccessful();
        $this->assertNull($c->refresh()->decrit_le);

        // Une image refusée, elle, ne se redemande pas sans fin.
        $this->artisan('usw:decrire')->assertSuccessful();
        $this->assertNotNull($c->refresh()->decrit_le);
        $this->assertNull($c->description_ia);
    }

    public function test_seulement_les_publications_en_ligne_les_plus_recentes_d_abord(): void
    {
        $brouillon = Contenu::factory()->brouillon()->create(['lieu_id' => $this->lieu->id]);
        $ancienne = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'publie_le' => now()->subDays(5)]);
        $recente = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'publie_le' => now()]);
        Http::fake(['*' => Http::response(['description' => 'Une rue.', 'mots' => ['rue']])]);

        $this->artisan('usw:decrire', ['--limite' => 1])->assertSuccessful();

        $this->assertNotNull($recente->refresh()->decrit_le);
        $this->assertNull($ancienne->refresh()->decrit_le);
        $this->assertNull($brouillon->refresh()->decrit_le);
    }
}
