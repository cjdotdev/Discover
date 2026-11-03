<?php

namespace Tests\Feature;

use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Son;
use App\Models\Utilisateur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Les sons à mettre sur un reel : le catalogue, la recherche, les favoris, la page d'un son. */
class SonsTest extends TestCase
{
    use RefreshDatabase;

    private function son(string $titre, string $categorie, int $reels = 0, bool $actif = true): Son
    {
        $s = Son::create([
            'cle' => 'test:'.$titre, 'titre' => $titre, 'artiste' => 'Kevin MacLeod', 'categorie' => $categorie,
            'duree_ms' => 180_000, 'chemin' => "sons/{$titre}.m4a", 'forme' => [10, 80, 40], 'debut_conseille_ms' => 30_000,
            'licence' => 'CC BY 4.0', 'attribution' => "« {$titre} » Kevin MacLeod (incompetech.com), licence CC BY 4.0", 'actif' => $actif,
        ]);
        Son::whereKey($s->id)->update(['nombre_reels' => $reels]);

        return $s->refresh();
    }

    public function test_le_catalogue_les_plus_utilises_d_abord_par_ambiance_et_par_recherche(): void
    {
        $this->son('Carefree', 'joyeux', 2);
        $this->son('Allada', 'afro', 9);
        $this->son('Zanzibar', 'afro', 1);
        $this->son('Retire', 'afro', 50, actif: false);

        $this->getJson('/api/v1/sons')->assertOk()->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.titre', 'Allada')->assertJsonPath('data.1.titre', 'Carefree')
            ->assertJsonPath('data.0.attribution', '« Allada » Kevin MacLeod (incompetech.com), licence CC BY 4.0')
            ->assertJsonPath('data.0.debut_conseille_ms', 30_000)->assertJsonPath('data.0.forme', [10, 80, 40])
            ->assertJsonPath('categories.0', 'afro')->assertJsonMissingPath('data.0.favori');
        $this->getJson('/api/v1/sons?categorie=afro')->assertJsonCount(2, 'data')->assertJsonPath('data.1.titre', 'Zanzibar');
        // Accents, majuscules et l'artiste comptent aussi.
        $this->getJson('/api/v1/sons?q=ZANZÌBAR')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/sons?q=macleod care')->assertJsonCount(1, 'data')->assertJsonPath('data.0.titre', 'Carefree');
        $this->getJson('/api/v1/sons?categorie=rap')->assertUnprocessable();
    }

    public function test_mes_sons_favoris(): void
    {
        $allada = $this->son('Allada', 'afro');
        $this->son('Carefree', 'joyeux');
        $moi = Utilisateur::factory()->create();

        $this->getJson('/api/v1/sons?categorie=favoris')->assertUnauthorized();
        $this->putJson("/api/v1/moi/sons/{$allada->ulid}")->assertUnauthorized();
        $this->actingAs($moi)->putJson("/api/v1/moi/sons/{$allada->ulid}")->assertNoContent();
        $this->actingAs($moi)->putJson("/api/v1/moi/sons/{$allada->ulid}")->assertNoContent();
        $this->actingAs($moi)->getJson('/api/v1/sons?categorie=favoris')->assertJsonCount(1, 'data')->assertJsonPath('data.0.favori', true);
        $this->actingAs($moi)->getJson('/api/v1/sons?categorie=joyeux')->assertJsonPath('data.0.favori', false);
        $this->actingAs($moi)->getJson("/api/v1/sons/{$allada->ulid}")->assertJsonPath('data.favori', true);

        $this->actingAs($moi)->deleteJson("/api/v1/moi/sons/{$allada->ulid}")->assertNoContent();
        $this->actingAs($moi)->getJson('/api/v1/sons?categorie=favoris')->assertJsonCount(0, 'data');
    }

    public function test_la_page_d_un_son_et_les_reels_qui_l_utilisent(): void
    {
        $allada = $this->son('Allada', 'afro');
        $lieu = Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'type' => 'Plages', 'latitude' => 6.3, 'longitude' => 2.0]);
        $aime = Contenu::factory()->reel()->complet()->create(['lieu_id' => $lieu->id, 'son_id' => $allada->id, 'son' => $allada->nomComplet(), 'nombre_reactions' => 12]);
        Contenu::factory()->reel()->complet()->create(['lieu_id' => $lieu->id, 'son_id' => $allada->id, 'son' => $allada->nomComplet()]);
        Contenu::factory()->reel()->complet()->create(['lieu_id' => $lieu->id]);

        $this->getJson("/api/v1/sons/{$allada->ulid}")->assertOk()->assertJsonPath('data.titre', 'Allada')->assertJsonPath('data.nombre_reels', 2);
        $this->getJson("/api/v1/sons/{$allada->ulid}/reels")->assertOk()->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $aime->ulid)->assertJsonPath('data.0.musique.titre', 'Allada')->assertJsonPath('data.0.son', 'Allada · Kevin MacLeod');
        $this->getJson('/api/v1/sons/inconnu')->assertNotFound();
    }
}
