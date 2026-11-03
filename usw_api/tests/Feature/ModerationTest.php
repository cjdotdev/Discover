<?php

namespace Tests\Feature;

use App\Enums\StatutContenu;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Pays;
use App\Models\Signalement;
use App\Models\Utilisateur;
use App\Models\Ville;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Lot 6 : la modération (E24, E25), pour l'administrateur seul. */
class ModerationTest extends TestCase
{
    use RefreshDatabase;

    private Utilisateur $admin;

    private Lieu $lieu;

    protected function setUp(): void
    {
        parent::setUp();
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $v = Ville::create(['pays_id' => $benin->id, 'nom' => 'Ouidah', 'region' => 'Atlantique']);
        $this->lieu = Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'ville_id' => $v->id, 'type' => 'Plages', 'latitude' => 6.3256, 'longitude' => 2.0886]);
        config(['discover.admins' => ['moi@discover.bj']]);
        $this->admin = Utilisateur::factory()->create(['email' => 'Moi@Discover.bj']);
    }

    public function test_seul_l_administrateur_voit_la_file(): void
    {
        // Pour tout autre compte, la file n'existe pas (404, pas 403).
        $this->actingAs(Utilisateur::factory()->create())->getJson('/api/v1/moderation/file')->assertNotFound();
        $this->actingAs($this->admin->refresh())->getJson('/api/v1/moderation/file')->assertOk()->assertJsonPath('totaux.a_verifier', 0);
        // Rien ne se voit sur le compte : il a l'air d'un compte comme les autres.
        $this->actingAs($this->admin)->getJson('/api/v1/moi')->assertJsonMissingPath('data.admin');
    }

    public function test_publier_ou_refuser_un_contenu_a_verifier(): void
    {
        $doute = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'statut' => StatutContenu::FileHumaine, 'motif' => 'La date de prise est dans le futur.', 'publie_le' => null, 'badge' => null]);
        $autre = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'statut' => StatutContenu::FileHumaine, 'motif' => 'La position de prise est impossible.', 'publie_le' => null, 'badge' => null]);

        $f = $this->actingAs($this->admin)->getJson('/api/v1/moderation/file')->assertOk();
        $f->assertJsonPath('totaux.a_verifier', 2)->assertJsonCount(2, 'data')->assertJsonPath('data.0.raison', 'La date de prise est dans le futur.');

        $this->actingAs($this->admin)->postJson("/api/v1/moderation/contenus/{$autre->ulid}/decision", ['decision' => 'refuser'])
            ->assertStatus(422)->assertJsonPath('message', 'Donnez le motif du refus : son auteur le lira.');
        $this->actingAs($this->admin)->postJson("/api/v1/moderation/contenus/{$autre->ulid}/decision", ['decision' => 'refuser', 'motif' => 'Pas pris au Bénin.'])
            ->assertOk()->assertJsonPath('statut', 'refuse');
        $this->assertSame('refusee', Utilisateur::find($autre->utilisateur_id)->notifications()->value('type'));

        $this->actingAs($this->admin)->postJson("/api/v1/moderation/contenus/{$doute->ulid}/decision", ['decision' => 'publier'])->assertOk();
        $this->assertSame(StatutContenu::Publie, $doute->refresh()->statut);
        $this->assertDatabaseCount('decisions_moderation', 2);
    }

    public function test_les_signalements_les_plus_nombreux_d_abord_puis_classer(): void
    {
        $c1 = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        $c2 = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        foreach ([[$c1, 1], [$c2, 3]] as [$c, $n]) {
            for ($i = 0; $i < $n; $i++) {
                Signalement::create(['utilisateur_id' => Utilisateur::factory()->create()->id, 'cible_type' => 'contenu', 'cible_id' => $c->id, 'motif' => 'Spam ou arnaque']);
            }
        }
        $com = Commentaire::create(['contenu_id' => $c1->id, 'utilisateur_id' => $this->admin->id, 'texte' => 'Achetez ici']);
        Signalement::create(['utilisateur_id' => Utilisateur::factory()->create()->id, 'cible_type' => 'commentaire', 'cible_id' => $com->id, 'motif' => 'Spam ou arnaque']);

        $f = $this->actingAs($this->admin)->getJson('/api/v1/moderation/file?file=signalements')->assertOk();
        $f->assertJsonPath('data.0.contenu.id', $c2->ulid)->assertJsonPath('data.0.signalements', 3)->assertJsonCount(1, 'commentaires');

        $this->actingAs($this->admin)->postJson("/api/v1/moderation/contenus/{$c2->ulid}/classer")->assertJsonPath('classes', 3);
        $this->actingAs($this->admin)->postJson("/api/v1/moderation/commentaires/{$com->ulid}/masquer")->assertJsonPath('masque', true);
        $this->getJson("/api/v1/contenus/{$c1->ulid}/commentaires")->assertJsonCount(0, 'data');
        $this->actingAs($this->admin)->getJson('/api/v1/moderation/file?file=signalements')->assertJsonCount(1, 'data')->assertJsonCount(0, 'commentaires');
    }
}
