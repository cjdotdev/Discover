<?php

namespace Tests\Feature;

use App\Enums\SourceCapture;
use App\Enums\StatutContenu;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\ModeleTelephone;
use App\Models\Pays;
use App\Models\Utilisateur;
use App\Models\Ville;
use App\Services\Contenus\Compteurs;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Lot 2 : les lieux et les contenus (E33, E05, E06). */
class LieuxEtContenusTest extends TestCase
{
    use RefreshDatabase;

    private function grandPopo(): Lieu
    {
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $ville = Ville::create(['pays_id' => $benin->id, 'nom' => 'Grand-Popo', 'region' => 'Mono']);

        return Lieu::create(['slug' => 'grand-popo', 'nom' => 'Plage de Grand-Popo', 'ville_id' => $ville->id, 'type' => 'Plages', 'latitude' => 6.2833, 'longitude' => 1.8222]);
    }

    public function test_les_relations_d_un_contenu(): void
    {
        $lieu = $this->grandPopo();
        $modele = ModeleTelephone::create(['marque' => 'Tecno', 'nom' => 'Camon 50 Pro']);
        $c = Contenu::factory()->complet($modele)->create(['lieu_id' => $lieu->id]);

        $c->load(['lieu.ville.pays', 'capture.modele', 'variantes', 'auteur']);
        $this->assertSame('Bénin', $c->lieu->ville->pays->nom);
        $this->assertSame('Tecno Camon 50 Pro', $c->capture->modele->complet());
        $this->assertCount(2, $c->variantes);
        $this->assertTrue($c->auteur->is(Utilisateur::find($c->utilisateur_id)));
        $this->assertSame('Mono, Bénin', $lieu->load('ville.pays')->region());
    }

    public function test_un_lieu_montre_ses_4_meilleures_photos_publiees(): void
    {
        $lieu = $this->grandPopo();
        Contenu::factory()->complet()->count(5)->sequence(fn ($s) => ['nombre_reactions' => $s->index * 10])->create(['lieu_id' => $lieu->id]);
        Contenu::factory()->brouillon()->create(['lieu_id' => $lieu->id, 'nombre_reactions' => 9999]);

        $r = $this->getJson('/api/v1/lieux/grand-popo')->assertOk();
        $r->assertJsonPath('data.id', 'grand-popo')
            ->assertJsonPath('data.region', 'Mono, Bénin')
            ->assertJsonPath('data.nombre_contenus', 5)
            ->assertJsonCount(4, 'data.photos')
            ->assertJsonPath('data.photos.0.compteurs.reactions', 40);
        $this->assertArrayHasKey('480', $r->json('data.photos.0.images'));
    }

    public function test_les_contenus_d_un_lieu_par_curseur_sans_les_brouillons(): void
    {
        $lieu = $this->grandPopo();
        $modele = ModeleTelephone::create(['marque' => 'Tecno', 'nom' => 'Camon 30']);
        Contenu::factory()->complet($modele)->count(25)->create(['lieu_id' => $lieu->id]);
        Contenu::factory()->brouillon()->create(['lieu_id' => $lieu->id]);

        $page1 = $this->getJson('/api/v1/lieux/grand-popo/contenus')->assertOk()->assertJsonCount(20, 'data');
        $suivant = $page1->json('meta.next_cursor');
        $this->assertNotNull($suivant);
        $this->assertSame('Tecno Camon 30', $page1->json('data.0.capture.telephone'));
        $this->assertArrayNotHasKey('statut', $page1->json('data.0'));

        $this->getJson('/api/v1/lieux/grand-popo/contenus?curseur='.$suivant)->assertOk()->assertJsonCount(5, 'data');
    }

    public function test_les_reels_filmes_dans_discover_ne_sont_que_dans_les_reels(): void
    {
        $lieu = $this->grandPopo();
        Contenu::factory()->complet()->count(3)->create(['lieu_id' => $lieu->id]);
        Contenu::factory()->complet()->reel()->count(2)->create(['lieu_id' => $lieu->id]);
        // Une video importee de la galerie, elle, est dans la pile de son lieu.
        $importee = Contenu::factory()->complet()->reel()->create(['lieu_id' => $lieu->id]);
        $importee->capture()->update(['source' => SourceCapture::Fichier]);

        $this->getJson('/api/v1/lieux/grand-popo/contenus')->assertOk()->assertJsonCount(4, 'data');
        $this->getJson('/api/v1/lieux/grand-popo/contenus?type=reel')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $importee->ulid);
        $this->getJson('/api/v1/lieux/grand-popo/contenus?type=video')->assertUnprocessable();
    }

    public function test_l_accueil_n_a_pas_de_pile_de_reels_filmes_dans_discover(): void
    {
        $plage = $this->grandPopo();
        Contenu::factory()->complet()->create(['lieu_id' => $plage->id]);
        Contenu::factory()->complet()->reel()->create(['lieu_id' => $plage->id]);
        $seulementDesReels = Lieu::create(['slug' => 'ganvie', 'nom' => 'Ganvié', 'ville_id' => $plage->ville_id, 'type' => 'Lacs', 'latitude' => 6.46, 'longitude' => 2.41]);
        Contenu::factory()->complet()->reel()->create(['lieu_id' => $seulementDesReels->id]);
        // En ligne, le compte se refait a la publication, la fiche de prise deja la.
        Compteurs::lieu($plage->id);
        Compteurs::lieu($seulementDesReels->id);

        $flux = $this->getJson('/api/v1/flux/decouverte')->assertOk();
        $this->assertSame(['grand-popo'], array_column($flux->json('data'), 'id'));
        $this->assertSame(['photo'], array_column($flux->json('data.0.photos'), 'type'));
        // Ils sont dans les Reels.
        $this->getJson('/api/v1/reels?abonnements=0&latitude=6.3&longitude=2&rayon=200')->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_pas_de_requetes_en_plus_quand_les_contenus_sont_plus_nombreux(): void
    {
        $lieu = $this->grandPopo();
        $compter = function () {
            DB::flushQueryLog();
            DB::enableQueryLog();
            $this->getJson('/api/v1/lieux/grand-popo/contenus')->assertOk();

            return count(DB::getQueryLog());
        };
        Contenu::factory()->complet()->count(3)->create(['lieu_id' => $lieu->id]);
        $peu = $compter();
        Contenu::factory()->complet()->count(12)->create(['lieu_id' => $lieu->id]);

        $this->assertSame($peu, $compter());
    }

    public function test_un_contenu_publie_se_voit_sans_compte(): void
    {
        $c = Contenu::factory()->complet()->create(['lieu_id' => $this->grandPopo()->id]);

        $this->getJson("/api/v1/contenus/{$c->ulid}")->assertOk()
            ->assertJsonPath('data.id', $c->ulid)
            ->assertJsonPath('data.lieu.id', 'grand-popo')
            ->assertJsonPath('data.lieu.region', 'Mono, Bénin')
            ->assertJsonPath('data.capture.origines.modele', 'exif')
            ->assertJsonMissingPath('data.auteur.email');
    }

    public function test_un_brouillon_n_existe_que_pour_son_auteur(): void
    {
        $c = Contenu::factory()->brouillon()->create();
        $autre = Utilisateur::factory()->create()->createToken('t')->plainTextToken;
        $sien = $c->auteur->createToken('t')->plainTextToken;

        $this->getJson("/api/v1/contenus/{$c->ulid}")->assertNotFound()->assertJsonPath('message', 'Introuvable.');
        $this->getJson("/api/v1/contenus/{$c->ulid}", ['Authorization' => "Bearer {$autre}"])->assertNotFound();
        // Une requete = un membre : le test oublie celui de la requete precedente.
        $this->app['auth']->forgetGuards();
        $this->getJson("/api/v1/contenus/{$c->ulid}", ['Authorization' => "Bearer {$sien}"])->assertOk()->assertJsonPath('data.statut', 'brouillon');
    }

    public function test_un_lieu_inconnu_repond_404_en_francais(): void
    {
        $this->getJson('/api/v1/lieux/nulle-part')->assertNotFound()->assertExactJson(['message' => 'Introuvable.']);
    }

    public function test_les_compteurs_suivent_la_publication(): void
    {
        $lieu = $this->grandPopo();
        $modele = ModeleTelephone::create(['marque' => 'Infinix', 'nom' => 'Note 40']);
        $c = Contenu::factory()->brouillon()->complet($modele)->create(['lieu_id' => $lieu->id]);
        $this->assertSame(0, $lieu->refresh()->nombre_contenus);

        $c->update(['statut' => StatutContenu::Publie, 'publie_le' => now()]);
        $this->assertSame(1, $lieu->refresh()->nombre_contenus);
        $this->assertSame(1, $modele->refresh()->nombre_contenus);

        $c->delete();
        $this->assertSame(0, $lieu->refresh()->nombre_contenus);
    }

    public function test_les_donnees_de_depart_n_inventent_rien(): void
    {
        $this->seed();

        $this->assertSame(0, Lieu::count());
        $this->assertSame(0, Contenu::count());
        $this->getJson('/api/v1/flux/decouverte')->assertOk()->assertJsonCount(0, 'data');
    }
}
