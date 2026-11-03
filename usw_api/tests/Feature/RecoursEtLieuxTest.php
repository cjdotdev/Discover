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
use App\Services\Contenus\Compteurs;
use App\Services\Lieux\TypeDeLieu;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** La seconde vérification, les lieux enregistrés, le nom libre, le type et les reels d'un lieu. */
class RecoursEtLieuxTest extends TestCase
{
    use RefreshDatabase;

    private Lieu $lieu;

    protected function setUp(): void
    {
        parent::setUp();
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $v = Ville::create(['pays_id' => $benin->id, 'nom' => 'Ouidah', 'region' => 'Atlantique']);
        $this->lieu = Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'ville_id' => $v->id, 'type' => 'Plages', 'latitude' => 6.3256, 'longitude' => 2.0886]);
    }

    public function test_l_auteur_d_un_refus_demande_une_seconde_verification_une_fois(): void
    {
        $c = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'statut' => StatutContenu::Refuse, 'motif' => 'Signes d’image générée.', 'publie_le' => null, 'badge' => null]);
        $auteur = Utilisateur::find($c->utilisateur_id);

        $this->actingAs(Utilisateur::factory()->create())->postJson("/api/v1/contenus/{$c->ulid}/verification")->assertForbidden();
        $this->actingAs($auteur)->getJson("/api/v1/contenus/{$c->ulid}")->assertJsonPath('data.recours', false);
        $this->actingAs($auteur)->postJson("/api/v1/contenus/{$c->ulid}/verification")->assertOk()
            ->assertJsonPath('message', 'Demande envoyée. L’équipe va revoir votre publication.');
        $this->assertSame(StatutContenu::FileHumaine, $c->refresh()->statut);
        $this->assertNotNull($c->recours_le);

        // L'équipe le voit dans « À vérifier », avec le motif du refus.
        config(['discover.admins' => ['moi@discover.bj']]);
        $admin = Utilisateur::factory()->create(['email' => 'moi@discover.bj']);
        $this->actingAs($admin)->getJson('/api/v1/moderation/file')->assertJsonPath('data.0.recours', true)
            ->assertJsonPath('data.0.raison', 'Seconde vérification demandée par l’auteur. Motif du refus : Signes d’image générée.');

        // Refusée à nouveau : pas de troisième passage.
        $this->actingAs($admin)->postJson("/api/v1/moderation/contenus/{$c->ulid}/decision", ['decision' => 'refuser', 'motif' => 'Image générée.'])->assertOk();
        $this->actingAs($auteur->refresh())->postJson("/api/v1/contenus/{$c->ulid}/verification")->assertStatus(422)
            ->assertJsonPath('message', 'Vous avez déjà demandé une seconde vérification pour cette publication.');
    }

    public function test_pas_de_seconde_verification_pour_une_publication_en_ligne_ou_un_refus_ancien(): void
    {
        $enLigne = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        $this->actingAs(Utilisateur::find($enLigne->utilisateur_id))->postJson("/api/v1/contenus/{$enLigne->ulid}/verification")
            ->assertStatus(422)->assertJsonPath('message', 'Cette publication n’est pas refusée.');

        $ancien = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'statut' => StatutContenu::Refuse, 'motif' => 'X', 'publie_le' => null]);
        Contenu::whereKey($ancien->id)->update(['updated_at' => now()->subDays(31)]);
        $this->actingAs(Utilisateur::find($ancien->utilisateur_id))->postJson("/api/v1/contenus/{$ancien->ulid}/verification")
            ->assertStatus(422)->assertJsonPath('message', 'Le délai de 30 jours pour demander une seconde vérification est dépassé.');
    }

    public function test_enregistrer_un_lieu_puis_le_retirer(): void
    {
        Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        $moi = Utilisateur::factory()->create();

        $this->getJson('/api/v1/lieux/ouidah')->assertOk()->assertJsonMissingPath('data.enregistre');
        $this->actingAs($moi)->getJson('/api/v1/lieux/ouidah')->assertJsonPath('data.enregistre', false);
        $this->actingAs($moi)->putJson('/api/v1/moi/lieux/ouidah')->assertNoContent();
        $this->actingAs($moi)->putJson('/api/v1/moi/lieux/ouidah')->assertNoContent();
        $this->actingAs($moi)->getJson('/api/v1/lieux/ouidah')->assertJsonPath('data.enregistre', true);
        $this->actingAs($moi)->getJson('/api/v1/moi/lieux')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', 'ouidah')->assertJsonCount(1, 'data.0.photos')->assertJsonPath('meta.next_cursor', null);

        $this->actingAs($moi)->deleteJson('/api/v1/moi/lieux/ouidah')->assertNoContent();
        $this->actingAs($moi)->getJson('/api/v1/moi/lieux')->assertJsonCount(0, 'data');
        $this->actingAs($moi)->putJson('/api/v1/moi/lieux/'.Lieu::sansLieu()->slug)->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->putJson('/api/v1/moi/lieux/ouidah')->assertUnauthorized();
    }

    public function test_un_lieu_sans_photos_sort_des_lieux_enregistres_avec_son_nom(): void
    {
        Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        $moi = Utilisateur::factory()->create();
        $this->actingAs($moi)->putJson('/api/v1/moi/lieux/ouidah')->assertNoContent();

        // Ses photos supprimées : il sort de la liste, son nom est dit une fois.
        Lieu::whereKey($this->lieu->id)->toBase()->update(['nombre_contenus' => 0]);
        $this->actingAs($moi)->getJson('/api/v1/moi/lieux')->assertOk()->assertJsonCount(0, 'data')
            ->assertJsonPath('retires.0.id', 'ouidah')->assertJsonPath('retires.0.nom', $this->lieu->nom);
        $this->actingAs($moi)->getJson('/api/v1/moi/lieux')->assertJsonCount(0, 'retires');
    }

    public function test_le_nom_libre(): void
    {
        $moi = Utilisateur::factory()->create(['nom_utilisateur' => 'kofi.a']);
        Utilisateur::factory()->create(['nom_utilisateur' => 'ama.b']);

        $this->getJson('/api/v1/auth/nom-libre?nom=x')->assertUnauthorized();
        $this->actingAs($moi)->getJson('/api/v1/auth/nom-libre?nom=ama.b')->assertJsonPath('libre', false)->assertJsonPath('message', 'Ce nom d’utilisateur est déjà pris.');
        $this->actingAs($moi)->getJson('/api/v1/auth/nom-libre?nom=@Ama.B')->assertJsonPath('libre', false);
        $this->actingAs($moi)->getJson('/api/v1/auth/nom-libre?nom=kofi.a')->assertJsonPath('libre', true);
        $this->actingAs($moi)->getJson('/api/v1/auth/nom-libre?nom=nouveau_nom')->assertJsonPath('libre', true);
        $this->actingAs($moi)->getJson('/api/v1/auth/nom-libre?nom=pas%20bon')->assertJsonPath('libre', false);
    }

    public function test_garder_un_commentaire_signale(): void
    {
        config(['discover.admins' => ['moi@discover.bj']]);
        $admin = Utilisateur::factory()->create(['email' => 'moi@discover.bj']);
        $c = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);
        $com = Commentaire::create(['contenu_id' => $c->id, 'utilisateur_id' => $admin->id, 'texte' => 'Très belle vue']);
        Signalement::create(['utilisateur_id' => Utilisateur::factory()->create()->id, 'cible_type' => 'commentaire', 'cible_id' => $com->id, 'motif' => 'Spam ou arnaque']);

        $this->actingAs($admin)->getJson('/api/v1/moderation/file?file=signalements')
            ->assertJsonPath('totaux.signalements', 0)->assertJsonPath('totaux.commentaires_signales', 1)->assertJsonCount(1, 'commentaires');
        $this->actingAs($admin)->postJson("/api/v1/moderation/commentaires/{$com->ulid}/classer")->assertOk()->assertJsonPath('classes', 1);
        $this->actingAs($admin)->getJson('/api/v1/moderation/file?file=signalements')
            ->assertJsonPath('totaux.commentaires_signales', 0)->assertJsonCount(0, 'commentaires');
        $this->assertFalse($com->refresh()->masque);
    }

    public function test_le_type_d_un_lieu_se_devine(): void
    {
        $this->assertSame('Cascades', TypeDeLieu::deviner('Chutes de Kota'));
        $this->assertSame('Lacs et lagunes', TypeDeLieu::deviner('Lac Ahémé'));
        $this->assertSame('Plages', TypeDeLieu::deviner('Plage de Fidjrossè'));
        $this->assertSame('Patrimoine', TypeDeLieu::deviner('Musée Honmè'));
        $this->assertSame('Collines', TypeDeLieu::deviner('Mont Sokbaro'));
        $this->assertSame('Forêts', TypeDeLieu::deviner('Forêt sacrée de Kpassè'));
        $this->assertSame('Plages', TypeDeLieu::deviner('Chez Théo', ['restaurant', 'beach']));
        $this->assertSame('Autres', TypeDeLieu::deviner('Chez ma grand-mère'));
    }

    public function test_un_lieu_qui_n_a_que_des_reels_est_sur_la_carte(): void
    {
        $reels = Lieu::create(['slug' => 'pendjari', 'nom' => 'Parc de la Pendjari', 'type' => 'Savane et parcs', 'latitude' => 11.1, 'longitude' => 1.5]);
        Contenu::factory()->reel()->complet()->create(['lieu_id' => $reels->id]);
        // Les compteurs se font a la mise en ligne, capture comprise (la fabrique l ajoute apres).
        Compteurs::lieu($reels->id);
        Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id]);

        $r = $this->getJson('/api/v1/carte?nord=12&sud=6&est=3&ouest=1')->assertOk()->assertJsonCount(2, 'data');
        $pendjari = collect($r->json('data'))->firstWhere('id', 'pendjari');
        $this->assertSame(1, $pendjari['nombre_reels']);
        $this->assertSame(1, $pendjari['nombre_verifiees']);
        $this->assertSame(1, $pendjari['nombre_contenus']);
        $this->assertCount(1, $pendjari['photos']);
        $this->assertSame(0, collect($r->json('data'))->firstWhere('id', 'ouidah')['nombre_reels']);
    }
}
