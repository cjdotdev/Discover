<?php

namespace Tests\Feature;

use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Pays;
use App\Models\Reaction;
use App\Models\Signalement;
use App\Models\Utilisateur;
use App\Models\Ville;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** « Gérer Discover » : l'équipe seule (ADMIN_EMAILS), les chiffres, les membres, la suspension. */
class AdministrationTest extends TestCase
{
    use RefreshDatabase;

    private Utilisateur $equipe;

    private Lieu $lieu;

    protected function setUp(): void
    {
        parent::setUp();
        config(['discover.admins' => ['equipe@discover.bj']]);
        $this->equipe = Utilisateur::factory()->create(['email' => 'equipe@discover.bj', 'nom_utilisateur' => 'equipe']);
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $v = Ville::create(['pays_id' => $benin->id, 'nom' => 'Ouidah', 'region' => 'Atlantique']);
        $this->lieu = Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'ville_id' => $v->id, 'type' => 'Plages', 'latitude' => 6.3256, 'longitude' => 2.0886]);
    }

    public function test_pour_tout_autre_compte_l_administration_n_existe_pas(): void
    {
        $this->getJson('/api/v1/admin/acces')->assertUnauthorized();
        $membre = Utilisateur::factory()->create();
        foreach (['acces', 'tableau', 'membres', "membres/{$membre->nom_utilisateur}"] as $chemin) {
            $this->actingAs($membre)->getJson("/api/v1/admin/$chemin")->assertNotFound();
        }
        $this->actingAs($this->equipe)->getJson('/api/v1/admin/acces')->assertOk()->assertJsonPath('ok', true);
    }

    public function test_l_activite_d_un_membre_est_notee_au_plus_toutes_les_deux_minutes(): void
    {
        $membre = Utilisateur::factory()->create();
        $jeton = $membre->createToken('Tecno')->plainTextToken;
        $this->withToken($jeton)->getJson('/api/v1/moi')->assertOk();
        $this->assertNotNull($membre->refresh()->derniere_activite_le);
        $this->assertSame(1, DB::table('activites_jour')->where('utilisateur_id', $membre->id)->count());
        $this->withToken($jeton)->getJson('/api/v1/moi')->assertOk();
        $this->assertSame(1, DB::table('activites_jour')->count());
    }

    public function test_le_tableau_de_bord_donne_les_chiffres_et_les_courbes(): void
    {
        $auteur = Utilisateur::factory()->create(['derniere_activite_le' => now()]);
        $c = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'utilisateur_id' => $auteur->id, 'publie_le' => now()]);
        Reaction::create(['utilisateur_id' => $this->equipe->id, 'contenu_id' => $c->id, 'type' => 'coeur']);
        DB::table('activites_jour')->insert(['utilisateur_id' => $auteur->id, 'jour' => now()->toDateString()]);

        $r = $this->actingAs($this->equipe)->getJson('/api/v1/admin/tableau?jours=7')->assertOk();
        $r->assertJsonPath('jours', 7)->assertJsonPath('maintenant.en_ligne', 1)->assertJsonPath('maintenant.membres', 2)
            ->assertJsonPath('maintenant.publications', 1)->assertJsonPath('periode.reactions.periode', 1)
            ->assertJsonCount(7, 'courbes.dates')->assertJsonPath('courbes.actifs.6', 1)
            ->assertJsonPath('lieux.0.nom', 'Ponton de Ouidah')->assertJsonPath('createurs.0.nom_utilisateur', $auteur->nom_utilisateur);
    }

    public function test_la_recherche_des_membres_ignore_accents_et_majuscules_et_filtre(): void
    {
        Utilisateur::factory()->create(['nom_affiche' => 'Sènan Hounkpè', 'nom_utilisateur' => 'senan.voyage', 'ville' => 'Grand-Popo']);
        Utilisateur::factory()->create(['nom_affiche' => 'Aïcha K.', 'nom_utilisateur' => 'aicha.k', 'ville' => 'Cotonou', 'suspendu_le' => now()]);

        $this->actingAs($this->equipe)->getJson('/api/v1/admin/membres?q=SENAN popo')->assertOk()
            ->assertJsonPath('total', 1)->assertJsonPath('data.0.nom_utilisateur', 'senan.voyage');
        $this->actingAs($this->equipe)->getJson('/api/v1/admin/membres?q=@aic')->assertJsonPath('data.0.nom_utilisateur', 'aicha.k');
        $this->actingAs($this->equipe)->getJson('/api/v1/admin/membres?filtre=suspendus')->assertJsonPath('total', 1)->assertJsonPath('data.0.suspendu', true);
        $this->actingAs($this->equipe)->getJson('/api/v1/admin/membres?tri=nom')->assertJsonPath('total', 3);
    }

    public function test_un_membre_suspendu_ne_peut_plus_entrer_et_ses_publications_se_cachent(): void
    {
        $membre = Utilisateur::factory()->create(['nom_utilisateur' => 'arnaque']);
        Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'utilisateur_id' => $membre->id]);
        $jeton = $membre->createToken('Tecno')->plainTextToken;
        Signalement::create(['utilisateur_id' => $this->equipe->id, 'cible_type' => 'utilisateur', 'cible_id' => $membre->id, 'motif' => 'Spam ou arnaque']);

        $this->actingAs($this->equipe)->getJson('/api/v1/admin/signalements/membres')->assertJsonPath('data.0.membre.nom_utilisateur', 'arnaque');
        $this->actingAs($this->equipe)->postJson('/api/v1/admin/membres/arnaque/suspension', [])->assertStatus(422);
        $this->actingAs($this->equipe)->postJson('/api/v1/admin/membres/arnaque/suspension', ['motif' => 'Arnaques répétées.'])
            ->assertOk()->assertJsonPath('membre.suspendu', true)->assertJsonPath('membre.motif_suspension', 'Arnaques répétées.');
        $this->assertSame(0, $membre->tokens()->count());
        $this->assertSame('traite', Signalement::first()->statut);
        $this->app['auth']->forgetGuards();
        $this->withToken($jeton)->getJson('/api/v1/moi')->assertUnauthorized();
        $this->assertSame(0, Contenu::publies()->count());

        $this->actingAs($this->equipe)->deleteJson('/api/v1/admin/membres/arnaque/suspension')->assertOk()->assertJsonPath('membre.suspendu', false);
        $this->assertSame(1, Contenu::publies()->count());
        // Pas soi-même.
        $this->actingAs($this->equipe)->postJson('/api/v1/admin/membres/equipe/suspension', ['motif' => 'Essai'])->assertStatus(422);
    }

    public function test_la_fiche_et_le_message_de_l_equipe(): void
    {
        $membre = Utilisateur::factory()->create(['nom_utilisateur' => 'kofi']);
        Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'utilisateur_id' => $membre->id]);
        $membre->createToken('Samsung Galaxy A55');

        $this->actingAs($this->equipe)->postJson('/api/v1/admin/membres/kofi/message', ['ton' => 'felicitations', 'texte' => 'Bravo pour vos photos de Ouidah !'])->assertCreated();
        $this->assertSame('equipe', $membre->notifications()->value('type'));

        $f = $this->actingAs($this->equipe)->getJson('/api/v1/admin/membres/kofi')->assertOk();
        $f->assertJsonPath('membre.nom_utilisateur', 'kofi')->assertJsonPath('compteurs.publications', 1)
            ->assertJsonCount(1, 'contenus')->assertJsonPath('appareils.0.nom', 'Samsung Galaxy A55')
            ->assertJsonPath('messages.0.ton', 'felicitations')->assertJsonCount(30, 'courbes.dates');
    }
}
