<?php

namespace Tests\Feature;

use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Utilisateur;
use App\Support\Themes;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Ce qu'on voit sur les photos : la recherche par ce qu'il y a dessus, et le rattrapage des anciennes. */
class EtiquettesTest extends TestCase
{
    use RefreshDatabase;

    private Lieu $lieu;

    protected function setUp(): void
    {
        parent::setUp();
        $this->lieu = Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'type' => 'Plages', 'latitude' => 6.3, 'longitude' => 2.0]);
    }

    public function test_les_mots_de_la_recherche_trouvent_ce_qu_il_y_a_sur_les_photos(): void
    {
        $this->assertContains('forest', Themes::etiquettesPour('arbre'));
        $this->assertContains('forest', Themes::etiquettesPour('Arbres'));
        $this->assertContains('beach', Themes::etiquettesPour('plage'));
        $this->assertContains('skyscraper', Themes::etiquettesPour('immeubles'));
        $this->assertContains('dog', Themes::etiquettesPour('animaux'));
        $this->assertSame(['dog'], Themes::etiquettesPour('dog'));
        $this->assertSame([], Themes::etiquettesPour('ouidah'));
        $this->assertContains('food', Themes::etiquettesDes(['nourriture', 'mer']));
    }

    public function test_chercher_arbre_trouve_les_photos_ou_il_y_a_des_arbres(): void
    {
        $foret = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'legende' => 'Un après-midi calme']);
        $foret->etiqueter([['nom' => 'Forest', 'confiance' => 0.91], ['nom' => 'Sky', 'confiance' => 0.7]]);
        $douteux = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'legende' => 'Autre chose']);
        $douteux->etiqueter([['nom' => 'Plant', 'confiance' => 0.4]]);
        $plat = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'legende' => 'Le déjeuner']);
        $plat->etiqueter([['nom' => 'Food', 'confiance' => 0.88]]);

        $this->getJson('/api/v1/recherche?q=arbre')->assertOk()->assertJsonCount(1, 'contenus')->assertJsonPath('contenus.0.id', $foret->ulid);
        $this->getJson('/api/v1/recherche?q=nourriture')->assertJsonCount(1, 'contenus')->assertJsonPath('contenus.0.id', $plat->ulid);
        // La légende compte toujours.
        $this->getJson('/api/v1/recherche?q=déjeuner')->assertJsonCount(1, 'contenus');
        $this->assertSame(['forest', 'sky'], $foret->etiquettes()->orderByDesc('confiance')->pluck('nom')->all());
        $this->assertNotNull($foret->refresh()->etiquete_le);
    }

    public function test_l_equipe_rattrape_les_photos_publiees_sans_etiquettes(): void
    {
        config(['discover.admins' => ['moi@discover.bj']]);
        $equipe = Utilisateur::factory()->create(['email' => 'moi@discover.bj']);
        $ancienne = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        $lue = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        $lue->etiqueter([['nom' => 'Beach', 'confiance' => 0.8]]);

        $this->actingAs(Utilisateur::factory()->create())->getJson('/api/v1/moderation/a-etiqueter')->assertNotFound();
        $r = $this->actingAs($equipe)->getJson('/api/v1/moderation/a-etiqueter')->assertOk();
        $this->assertSame([$ancienne->ulid], array_column($r->json('data'), 'id'));

        $this->actingAs($equipe)->putJson("/api/v1/moderation/contenus/{$ancienne->ulid}/etiquettes", ['etiquettes' => [['nom' => 'Dog', 'confiance' => 0.93]]])->assertNoContent();
        // Lue : elle ne revient plus dans la liste.
        $this->actingAs($equipe)->getJson('/api/v1/moderation/a-etiqueter')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/recherche?q=chien')->assertJsonPath('contenus.0.id', $ancienne->ulid);
    }
}
