<?php

namespace Tests\Feature;

use App\Models\Abonnement;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Utilisateur;
use App\Services\Contenus\Recommandation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class VuesEtRecommandationTest extends TestCase
{
    use RefreshDatabase;

    private function vue(string $ulid, int $ms, bool $complete = false, string $ip = '10.0.0.1'): TestResponse
    {
        return $this->withServerVariables(['REMOTE_ADDR' => $ip])
            ->postJson('/api/v1/vues', ['vues' => [['contenu' => $ulid, 'duree_ms' => $ms, 'complete' => $complete]]]);
    }

    public function test_une_vue_compte_une_fois_par_personne_et_par_jour_apres_2_secondes(): void
    {
        $photo = Contenu::factory()->create();

        $this->vue($photo->ulid, 1500)->assertOk();
        $this->assertSame(0, $photo->fresh()->nombre_vues);
        $this->vue($photo->ulid, 2500)->assertOk();
        $this->vue($photo->ulid, 9000)->assertOk();
        $this->assertSame(1, $photo->fresh()->nombre_vues);

        // Un autre téléphone (une autre adresse), puis le lendemain : deux vues de plus. Changer
        // l'en-tête X-Appareil ne suffit plus à compter deux fois.
        $this->withHeader('X-Appareil', 'ffffeeeeddddcccc')->vue($photo->ulid, 2500);
        $this->assertSame(1, $photo->fresh()->nombre_vues);
        $this->vue($photo->ulid, 2500, ip: '10.0.0.2');
        $this->travel(1)->days();
        $this->vue($photo->ulid, 2500);
        $this->assertSame(3, $photo->fresh()->nombre_vues);
    }

    public function test_un_reel_regarde_jusqu_au_bout_et_ses_propres_vues(): void
    {
        $reel = Contenu::factory()->reel()->create();

        $this->vue($reel->ulid, 2500)->assertOk();
        $this->assertSame(0, $reel->fresh()->nombre_vues);
        $this->vue($reel->ulid, 4000);
        $this->vue($reel->ulid, 24000, complete: true);
        $this->vue($reel->ulid, 24000, complete: true);
        $this->assertSame([1, 1], [$reel->fresh()->nombre_vues, $reel->fresh()->nombre_vues_completes]);

        // Son auteur ne se compte pas ; un brouillon ne se compte pas.
        $this->actingAs($reel->auteur)->postJson('/api/v1/vues', ['vues' => [['contenu' => $reel->ulid, 'duree_ms' => 9000]]])->assertOk();
        $brouillon = Contenu::factory()->brouillon()->create();
        $this->vue($brouillon->ulid, 9000);
        $this->assertSame(1, $reel->fresh()->nombre_vues);
        $this->assertSame(0, $brouillon->fresh()->nombre_vues);
        $this->getJson("/api/v1/contenus/{$reel->ulid}")->assertJsonPath('data.compteurs.vues', 1);
    }

    public function test_le_score_monte_avec_l_engagement_et_baisse_avec_l_age(): void
    {
        $neuve = Contenu::factory()->create(['publie_le' => now()]);
        $aimee = Contenu::factory()->create(['publie_le' => now(), 'nombre_reactions' => 20, 'nombre_enregistrements' => 5]);
        $vieille = Contenu::factory()->create(['publie_le' => now()->subDays(20), 'nombre_reactions' => 20, 'nombre_enregistrements' => 5]);

        $this->assertGreaterThan(Recommandation::score($neuve), Recommandation::score($aimee));
        $this->assertGreaterThan(Recommandation::score($vieille), Recommandation::score($aimee));
        // Une publication toute neuve passe devant une vieille très aimée : elle a sa chance.
        $this->assertGreaterThan(Recommandation::score($vieille), Recommandation::score($neuve));

        $this->artisan('usw:scores')->assertSuccessful();
        $this->assertGreaterThan(0, $aimee->fresh()->score);
        $this->assertGreaterThan(0, Lieu::find($aimee->lieu_id)->fresh()->score);
    }

    public function test_pour_toi_remonte_les_createurs_suivis_descend_les_reels_vus_et_varie_les_createurs(): void
    {
        $moi = Utilisateur::factory()->create();
        $suivi = Utilisateur::factory()->create();
        $autre = Utilisateur::factory()->create();
        Abonnement::create(['abonne_id' => $moi->id, 'createur_id' => $suivi->id]);
        $populaire = Contenu::factory()->reel()->create(['utilisateur_id' => $autre->id, 'publie_le' => now(), 'nombre_reactions' => 30]);
        $populaire2 = Contenu::factory()->reel()->create(['utilisateur_id' => $autre->id, 'publie_le' => now(), 'nombre_reactions' => 25]);
        $duSuivi = Contenu::factory()->reel()->create(['utilisateur_id' => $suivi->id, 'publie_le' => now(), 'nombre_reactions' => 12]);
        $discret = Contenu::factory()->reel()->create(['publie_le' => now(), 'nombre_reactions' => 1]);
        $this->artisan('usw:scores');

        $ids = fn () => array_column($this->actingAs($moi)->getJson('/api/v1/reels')->assertOk()->json('data'), 'id');
        // Le créateur suivi passe devant ; puis les deux reels du même créateur ne se suivent pas.
        $this->assertSame([$duSuivi->ulid, $populaire->ulid, $discret->ulid, $populaire2->ulid], $ids());

        // Vu en entier : il descend (la première page refait l'ordre).
        $this->actingAs($moi)->postJson('/api/v1/vues', ['vues' => [['contenu' => $populaire->ulid, 'duree_ms' => 24000, 'complete' => true]]]);
        $this->assertSame([$duSuivi->ulid, $populaire2->ulid], array_slice($ids(), 0, 2));
    }

    public function test_pour_toi_par_pages_et_l_accueil_par_score(): void
    {
        Contenu::factory()->reel()->count(13)->create(['publie_le' => now()]);
        $this->artisan('usw:scores');

        $premiere = $this->getJson('/api/v1/reels', ['X-Appareil' => 'a1b2c3d4e5f60718'])->assertOk();
        $this->assertCount(10, $premiere->json('data'));
        $this->assertSame('10', $premiere->json('meta.next_cursor'));
        $seconde = $this->getJson('/api/v1/reels?curseur=10', ['X-Appareil' => 'a1b2c3d4e5f60718'])->assertOk();
        $this->assertCount(3, $seconde->json('data'));
        $this->assertNull($seconde->json('meta.next_cursor'));
        $this->assertEmpty(array_intersect(array_column($premiere->json('data'), 'id'), array_column($seconde->json('data'), 'id')));

        // L'accueil : le lieu le mieux noté d'abord, même s'il a moins de publications.
        [$a, $b] = Lieu::factory()->count(2)->create();
        Contenu::factory()->count(3)->create(['lieu_id' => $a->id, 'publie_le' => now()->subDays(40)]);
        Contenu::factory()->create(['lieu_id' => $b->id, 'publie_le' => now(), 'nombre_reactions' => 50]);
        Lieu::whereKey($a->id)->update(['nombre_contenus' => 3]);
        Lieu::whereKey($b->id)->update(['nombre_contenus' => 1]);
        $this->artisan('usw:scores');
        $ordre = array_column($this->getJson('/api/v1/flux/decouverte')->json('data'), 'id');
        $this->assertLessThan(array_search($a->slug, $ordre, true), array_search($b->slug, $ordre, true));
    }

    public function test_pas_interesse_retire_la_publication_et_descend_son_createur(): void
    {
        $moi = Utilisateur::factory()->create();
        $lasse = Utilisateur::factory()->create();
        $ecarte = Contenu::factory()->reel()->create(['utilisateur_id' => $lasse->id, 'publie_le' => now(), 'nombre_reactions' => 40]);
        $memeCreateur = Contenu::factory()->reel()->create(['utilisateur_id' => $lasse->id, 'publie_le' => now(), 'nombre_reactions' => 40]);
        $autre = Contenu::factory()->reel()->create(['publie_le' => now(), 'nombre_reactions' => 8]);
        $this->artisan('usw:scores');

        $this->actingAs($moi)->postJson("/api/v1/contenus/{$ecarte->ulid}/pas-interesse")->assertNoContent();
        $ids = array_column($this->actingAs($moi)->getJson('/api/v1/reels')->json('data'), 'id');
        $this->assertSame([$autre->ulid, $memeCreateur->ulid], $ids);
    }

    public function test_la_reponse_donne_le_nombre_de_vues_a_jour(): void
    {
        $photo = Contenu::factory()->create(['nombre_vues' => 4]);

        // Une durée de 0 ne compte pas : elle redemande seulement le nombre.
        $this->vue($photo->ulid, 0)->assertOk()->assertJsonPath("vues.{$photo->ulid}", 4);
        $this->vue($photo->ulid, 2500)->assertOk()->assertJsonPath("vues.{$photo->ulid}", 5);
    }

    public function test_seul_l_auteur_voit_qui_a_vu_sa_publication(): void
    {
        $photo = Contenu::factory()->create();
        $ami = Utilisateur::factory()->create();
        $curieux = Utilisateur::factory()->create();
        $this->actingAs($ami)->postJson('/api/v1/vues', ['vues' => [['contenu' => $photo->ulid, 'duree_ms' => 3000]]]);
        $this->app['auth']->forgetGuards();
        $this->vue($photo->ulid, 3000, ip: '10.0.0.9');

        $this->app['auth']->forgetGuards();
        $this->actingAs($photo->auteur)->getJson("/api/v1/contenus/{$photo->ulid}/spectateurs")->assertOk()
            ->assertJsonPath('total', 2)
            ->assertJsonPath('sans_compte', 1)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.membre.nom_utilisateur', $ami->nom_utilisateur);
        $this->app['auth']->forgetGuards();
        $this->actingAs($curieux)->getJson("/api/v1/contenus/{$photo->ulid}/spectateurs")->assertNotFound();
    }
}
