<?php

namespace Tests\Feature;

use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Pays;
use App\Models\Utilisateur;
use App\Models\Ville;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Lot 4 : explorer (E03, E04, E06, E11, E20, E31), sans compte. */
class ExplorationTest extends TestCase
{
    use RefreshDatabase;

    private Pays $benin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
    }

    private function lieu(string $slug, string $nom, string $ville, string $type, float $lat, float $lon, int $photos = 2): Lieu
    {
        $v = Ville::firstOrCreate(['pays_id' => $this->benin->id, 'nom' => $ville], ['region' => 'Mono']);
        $l = Lieu::create(['slug' => $slug, 'nom' => $nom, 'ville_id' => $v->id, 'type' => $type, 'latitude' => $lat, 'longitude' => $lon]);
        if ($photos > 0) {
            Contenu::factory()->complet()->count($photos)->create(['lieu_id' => $l->id]);
        }

        return $l->refresh();
    }

    public function test_decouverte_donne_les_lieux_avec_leur_pile_les_plus_fournis_d_abord(): void
    {
        $this->lieu('grand-popo', 'Plage de Grand-Popo', 'Grand-Popo', 'Plages', 6.28, 1.82, 5);
        $this->lieu('kota', 'Cascade de Kota', 'Natitingou', 'Cascades', 10.26, 1.43, 2);
        $this->lieu('vide', 'Lieu sans photo', 'Cotonou', 'Plages', 6.36, 2.42, 0);

        $r = $this->getJson('/api/v1/flux/decouverte')->assertOk();
        $this->assertSame(['grand-popo', 'kota'], array_column($r->json('data'), 'id'));
        $r->assertJsonCount(4, 'data.0.photos')->assertJsonPath('data.0.region', 'Mono, Bénin');
        $this->assertArrayHasKey('480', $r->json('data.0.photos.0.images'));
    }

    public function test_decouverte_ne_fait_pas_une_requete_par_lieu(): void
    {
        for ($i = 0; $i < 6; $i++) {
            $this->lieu("lieu-{$i}", "Lieu {$i}", 'Cotonou', 'Plages', 6.3 + $i / 100, 2.4, 2);
        }
        DB::enableQueryLog();
        $this->getJson('/api/v1/flux/decouverte')->assertOk()->assertJsonCount(6, 'data');
        $avecSix = count(DB::getQueryLog());
        // Les lieux, leurs villes, leurs pays, leurs piles, leurs images, leurs auteurs et leurs
        // fiches de prise, puis la pile « Sans lieu » : un nombre fixe, quel que soit le nombre de lieux.
        $this->assertLessThanOrEqual(10, $avecSix);
        for ($i = 6; $i < 12; $i++) {
            $this->lieu("lieu-{$i}", "Lieu {$i}", 'Cotonou', 'Plages', 6.3 + $i / 100, 2.4, 2);
        }
        Cache::flush();
        DB::flushQueryLog();
        $this->getJson('/api/v1/flux/decouverte')->assertOk()->assertJsonCount(12, 'data');
        $this->assertSame($avecSix, count(DB::getQueryLog()));
    }

    public function test_decouverte_par_curseur_et_par_type(): void
    {
        for ($i = 0; $i < 22; $i++) {
            $this->lieu("plage-{$i}", "Plage {$i}", 'Ouidah', 'Plages', 6.3, 2.0 + $i / 100, 1);
        }
        $this->lieu('kota', 'Cascade de Kota', 'Natitingou', 'Cascades', 10.26, 1.43, 1);

        $page = $this->getJson('/api/v1/flux/decouverte')->assertOk()->assertJsonCount(20, 'data');
        $suite = $page->json('meta.next_cursor');
        $this->assertNotNull($suite);
        $this->getJson('/api/v1/flux/decouverte?curseur='.$suite)->assertOk()->assertJsonCount(3, 'data');

        $this->getJson('/api/v1/flux/decouverte?types=Cascades')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', 'kota');
    }

    public function test_un_contenu_publie_renouvelle_l_accueil_garde_en_cache(): void
    {
        $l = $this->lieu('grand-popo', 'Plage de Grand-Popo', 'Grand-Popo', 'Plages', 6.28, 1.82, 1);
        $this->getJson('/api/v1/flux/decouverte')->assertJsonPath('data.0.nombre_contenus', 1);

        Contenu::factory()->complet()->create(['lieu_id' => $l->id]);
        $this->getJson('/api/v1/flux/decouverte')->assertJsonPath('data.0.nombre_contenus', 2);
    }

    public function test_pres_de_moi_trie_par_distance_dans_le_rayon(): void
    {
        $this->lieu('ouidah', 'Ponton de Ouidah', 'Ouidah', 'Plages', 6.3256, 2.0886);
        $this->lieu('grand-popo', 'Plage de Grand-Popo', 'Grand-Popo', 'Plages', 6.2833, 1.8222);
        $this->lieu('kota', 'Cascade de Kota', 'Natitingou', 'Cascades', 10.2667, 1.4333);

        // Depuis Cotonou : Ouidah (≈ 37 km), puis Grand-Popo (≈ 66 km) ; Kota est trop loin.
        $r = $this->getJson('/api/v1/flux/pres-de-moi?latitude=6.3654&longitude=2.4183&rayon=100')->assertOk();
        $this->assertSame(['ouidah', 'grand-popo'], array_column($r->json('data'), 'id'));
        $this->assertEqualsWithDelta(37, $r->json('data.0.distance_km'), 3);

        $this->getJson('/api/v1/flux/pres-de-moi?latitude=6.3654')->assertStatus(422);
    }

    public function test_les_reels_les_plus_recents_d_abord_et_pres_de_moi(): void
    {
        $ouidah = $this->lieu('ouidah', 'Ponton de Ouidah', 'Ouidah', 'Plages', 6.3256, 2.0886, 0);
        $kota = $this->lieu('kota', 'Cascade de Kota', 'Natitingou', 'Cascades', 10.2667, 1.4333, 0);
        $ancien = Contenu::factory()->complet()->reel()->create(['lieu_id' => $kota->id, 'publie_le' => now()->subDays(3)]);
        $recent = Contenu::factory()->complet()->reel()->create(['lieu_id' => $ouidah->id, 'publie_le' => now()->subHour()]);
        Contenu::factory()->complet()->create(['lieu_id' => $ouidah->id]);
        Contenu::factory()->complet()->reel()->brouillon()->create(['lieu_id' => $ouidah->id]);

        $r = $this->getJson('/api/v1/reels')->assertOk();
        $this->assertSame([$recent->ulid, $ancien->ulid], array_column($r->json('data'), 'id'));
        $r->assertJsonPath('data.0.lieu.id', 'ouidah')->assertJsonPath('data.0.duree', 24);

        $this->getJson('/api/v1/reels?latitude=6.3654&longitude=2.4183')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $recent->ulid);
    }

    public function test_la_carte_donne_les_lieux_de_la_zone_avec_une_photo(): void
    {
        $this->lieu('ouidah', 'Ponton de Ouidah', 'Ouidah', 'Plages', 6.3256, 2.0886);
        $this->lieu('kota', 'Cascade de Kota', 'Natitingou', 'Cascades', 10.2667, 1.4333);

        $r = $this->getJson('/api/v1/carte?nord=7&sud=6&est=3&ouest=1')->assertOk();
        $r->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', 'ouidah')->assertJsonCount(1, 'data.0.photos');
        $this->getJson('/api/v1/carte?nord=12&sud=6&est=3&ouest=1&types=Cascades')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', 'kota');
        $this->getJson('/api/v1/carte?nord=5&sud=7&est=3&ouest=1')->assertStatus(422);
    }

    public function test_la_recherche_trouve_lieux_et_createurs_sans_les_accents(): void
    {
        $l = $this->lieu('aheme', 'Lac Ahémé, Possotomé', 'Possotomé', 'Lacs et lagunes', 6.51, 1.98, 0);
        $aicha = Utilisateur::factory()->create(['nom_utilisateur' => 'aicha.k', 'nom_affiche' => 'Aïcha K.']);
        Contenu::factory()->complet()->create(['lieu_id' => $l->id, 'utilisateur_id' => $aicha->id]);
        Utilisateur::factory()->create(['nom_utilisateur' => 'aicha.sans.photo']);
        Utilisateur::factory()->create(['nom_utilisateur' => 'aicha.partie', 'suppression_demandee_le' => now()]);

        $this->getJson('/api/v1/recherche?q=aheme')->assertOk()->assertJsonPath('lieux.0.id', 'aheme');
        $this->getJson('/api/v1/recherche?q=Ahémé')->assertOk()->assertJsonPath('lieux.0.id', 'aheme');
        $this->getJson('/api/v1/recherche?q=possotome')->assertOk()->assertJsonPath('lieux.0.id', 'aheme');

        $r = $this->getJson('/api/v1/recherche?q=@aicha')->assertOk();
        $this->assertSame(['aicha.k'], array_column($r->json('createurs'), 'nom_utilisateur'));
        $r->assertJsonPath('createurs.0.nombre_contenus', 1);
        $this->assertArrayNotHasKey('email', $r->json('createurs.0'));
        $this->getJson('/api/v1/recherche?q=')->assertStatus(422);
    }

    public function test_la_recherche_trouve_les_publications_par_legende_et_par_lieu(): void
    {
        $l = $this->lieu('ouidah', 'Ponton de Ouidah', 'Ouidah', 'Plages', 6.3256, 2.0886, 0);
        $c = Contenu::factory()->complet()->create(['lieu_id' => $l->id, 'legende' => 'Coucher de soleil sur la lagune']);
        Contenu::factory()->complet()->create(['legende' => 'Marché de Dantokpa']);
        Contenu::factory()->brouillon()->create(['lieu_id' => $l->id, 'legende' => 'Coucher en brouillon']);

        $this->getJson('/api/v1/recherche?q=coucher')->assertOk()->assertJsonCount(1, 'contenus')->assertJsonPath('contenus.0.id', $c->ulid);
        $this->getJson('/api/v1/recherche?q=lagune ouidah')->assertOk()->assertJsonCount(1, 'contenus');
        $this->getJson('/api/v1/recherche?q=ouidah')->assertOk()->assertJsonCount(1, 'contenus');
        $this->getJson('/api/v1/recherche?q=pendjari')->assertOk()->assertJsonCount(0, 'contenus');
    }

    public function test_le_profil_d_un_createur_et_ses_publications(): void
    {
        $l = $this->lieu('ouidah', 'Ponton de Ouidah', 'Ouidah', 'Plages', 6.3256, 2.0886, 0);
        $u = Utilisateur::factory()->create(['nom_utilisateur' => 'senan.voyage', 'nom_affiche' => 'Sènan Voyage', 'bio' => 'Les cascades du Nord.', 'ville' => 'Natitingou']);
        Contenu::factory()->complet()->count(3)->create(['lieu_id' => $l->id, 'utilisateur_id' => $u->id]);
        Contenu::factory()->brouillon()->create(['lieu_id' => $l->id, 'utilisateur_id' => $u->id]);

        $this->getJson('/api/v1/utilisateurs/@senan.voyage')->assertOk()
            ->assertJsonPath('data.nom_affiche', 'Sènan Voyage')
            ->assertJsonPath('data.ville', 'Natitingou, Bénin')
            ->assertJsonPath('data.compteurs.contenus', 3)
            ->assertJsonMissingPath('data.email');
        $this->getJson('/api/v1/utilisateurs/senan.voyage/contenus')->assertOk()
            ->assertJsonCount(3, 'data')->assertJsonPath('data.0.auteur.nom_utilisateur', 'senan.voyage');
        $this->getJson('/api/v1/utilisateurs/personne')->assertNotFound();
    }

    public function test_mes_contenus_montrent_aussi_les_brouillons_et_les_refus(): void
    {
        $l = $this->lieu('ouidah', 'Ponton de Ouidah', 'Ouidah', 'Plages', 6.3256, 2.0886, 0);
        $moi = Utilisateur::factory()->create();
        Contenu::factory()->complet()->create(['lieu_id' => $l->id, 'utilisateur_id' => $moi->id]);
        Contenu::factory()->brouillon()->create(['lieu_id' => $l->id, 'utilisateur_id' => $moi->id]);
        Contenu::factory()->complet()->create(['lieu_id' => $l->id]);

        $r = $this->actingAs($moi)->getJson('/api/v1/moi/contenus')->assertOk()->assertJsonCount(2, 'data');
        $this->assertEqualsCanonicalizing(['publie', 'brouillon'], array_column($r->json('data'), 'statut'));
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/moi/contenus')->assertUnauthorized();
    }
}
