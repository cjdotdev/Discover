<?php

namespace Tests\Feature;

use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Pays;
use App\Models\Utilisateur;
use App\Models\Ville;
use App\Notifications\Activite;
use App\Support\Medias;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Lot 5 : la communauté (E06, E07, E09, E10, E19, E20, E22) et le centre des notifications (E17). */
class CommunauteTest extends TestCase
{
    use RefreshDatabase;

    private Lieu $lieu;

    private Utilisateur $auteur;

    private Contenu $photo;

    protected function setUp(): void
    {
        parent::setUp();
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $v = Ville::create(['pays_id' => $benin->id, 'nom' => 'Ouidah', 'region' => 'Atlantique']);
        $this->lieu = Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'ville_id' => $v->id, 'type' => 'Plages', 'latitude' => 6.3256, 'longitude' => 2.0886]);
        $this->auteur = Utilisateur::factory()->create(['nom_utilisateur' => 'aicha.k', 'nom_affiche' => 'Aïcha K.']);
        $this->photo = Contenu::factory()->complet()->create(['lieu_id' => $this->lieu->id, 'utilisateur_id' => $this->auteur->id]);
    }

    private function membre(string $pseudo): Utilisateur
    {
        return Utilisateur::factory()->create(['nom_utilisateur' => $pseudo, 'nom_affiche' => ucfirst($pseudo)]);
    }

    private function url(string $suite = ''): string
    {
        return "/api/v1/contenus/{$this->photo->ulid}{$suite}";
    }

    public function test_une_reaction_par_membre_qui_se_change_et_se_retire(): void
    {
        $kofi = $this->membre('kofi');
        $this->actingAs($kofi)->putJson($this->url('/reaction'), ['type' => 'coeur'])->assertOk()->assertJsonPath('reactions', 1);
        $this->actingAs($kofi)->putJson($this->url('/reaction'), ['type' => 'voyage'])->assertOk()->assertJsonPath('reactions', 1);
        $this->actingAs($this->membre('ola'))->putJson($this->url('/reaction'), ['type' => 'coeur'])->assertJsonPath('reactions', 2);
        $this->actingAs($kofi)->putJson($this->url('/reaction'), ['type' => 'pouce'])->assertStatus(422);

        $r = $this->getJson($this->url('/reactions'))->assertOk();
        $r->assertJsonPath('total', 2)->assertJsonPath('totaux.coeur', 1)->assertJsonPath('totaux.voyage', 1);
        $this->getJson($this->url('/reactions?type=voyage'))->assertJsonCount(1, 'data')->assertJsonPath('data.0.membre.nom_utilisateur', 'kofi');

        // Ma réaction revient avec la publication.
        $this->actingAs($kofi)->getJson($this->url())->assertJsonPath('data.moi.reaction', 'voyage');
        $this->actingAs($kofi)->deleteJson($this->url('/reaction'))->assertOk()->assertJsonPath('reactions', 1);
        $this->assertSame(1, $this->photo->refresh()->nombre_reactions);
    }

    public function test_reagir_previent_l_auteur_mais_pas_soi_meme(): void
    {
        $this->actingAs($this->membre('kofi'))->putJson($this->url('/reaction'), ['type' => 'waouh']);
        $this->actingAs($this->auteur)->putJson($this->url('/reaction'), ['type' => 'coeur']);

        $n = $this->actingAs($this->auteur)->getJson('/api/v1/notifications')->assertOk();
        $n->assertJsonCount(1, 'data')->assertJsonPath('data.0.genre', 'reaction')->assertJsonPath('data.0.acteur.nom_utilisateur', 'kofi')
            ->assertJsonPath('non_lues', 1)->assertJsonPath('data.0.contenu.lieu', 'ouidah');
        $this->actingAs($this->auteur)->postJson('/api/v1/notifications/lues')->assertJsonPath('non_lues', 0);
    }

    public function test_une_notification_montre_la_photo_et_le_nom_du_jour(): void
    {
        $kofi = $this->membre('kofi');
        $this->actingAs($kofi)->putJson($this->url('/reaction'), ['type' => 'waouh']);
        $this->actingAs($this->auteur)->getJson('/api/v1/notifications')->assertJsonPath('data.0.acteur.nom_utilisateur', 'kofi')->assertJsonPath('data.0.acteur.avatar', null);

        // Il change de photo et de nom ensuite : l'adresse gardée dans la notification ne vaut plus rien.
        $kofi->forceFill(['avatar' => 'avatars/nouvelle.webp', 'nom_affiche' => 'Kofi A.', 'nom_utilisateur' => 'kofi.a'])->save();
        $this->actingAs($this->auteur)->getJson('/api/v1/notifications')->assertOk()
            ->assertJsonPath('data.0.acteur.nom_utilisateur', 'kofi.a')
            ->assertJsonPath('data.0.acteur.nom_affiche', 'Kofi A.')
            ->assertJsonPath('data.0.acteur.avatar', Medias::public()->url('avatars/nouvelle.webp'));
    }

    public function test_un_brouillon_d_un_autre_n_existe_pas(): void
    {
        $brouillon = Contenu::factory()->brouillon()->create(['lieu_id' => $this->lieu->id, 'utilisateur_id' => $this->auteur->id]);
        $this->actingAs($this->membre('kofi'))->putJson("/api/v1/contenus/{$brouillon->ulid}/reaction", ['type' => 'coeur'])->assertNotFound();
        $this->actingAs($this->membre('ola'))->postJson("/api/v1/contenus/{$brouillon->ulid}/commentaires", ['texte' => 'Bonjour'])->assertNotFound();
    }

    public function test_commenter_repondre_et_mentionner(): void
    {
        $kofi = $this->membre('kofi');
        $ola = $this->membre('ola');

        $c = $this->actingAs($kofi)->postJson($this->url('/commentaires'), ['texte' => '  Quelle lumière !   Merci  '])
            ->assertCreated()->assertJsonPath('data.texte', 'Quelle lumière ! Merci')->json('data.id');
        // Une réponse à une réponse se range sous le même fil.
        $r1 = $this->actingAs($this->auteur)->postJson($this->url('/commentaires'), ['texte' => 'Merci @kofi, venez à 17 h.', 'parent' => $c])
            ->assertCreated()->assertJsonPath('data.repond_a.nom_utilisateur', 'kofi')->assertJsonPath('data.de_l_auteur', true)->json('data.id');
        $this->actingAs($ola)->postJson($this->url('/commentaires'), ['texte' => 'Je confirme, @aicha.k.', 'parent' => $r1])
            ->assertCreated()->assertJsonPath('data.repond_a.nom_utilisateur', 'aicha.k');

        $liste = $this->getJson($this->url('/commentaires'))->assertOk();
        $liste->assertJsonCount(1, 'data')->assertJsonPath('data.0.reponses', 2);
        $this->getJson("/api/v1/commentaires/{$c}/reponses")->assertOk()->assertJsonCount(2, 'data');
        $this->assertSame(3, $this->photo->refresh()->nombre_commentaires);

        // Kofi : la réponse (pas une deuxième notification pour la mention) ; l'auteur : le commentaire et la mention.
        $this->assertSame(['reponse'], $kofi->notifications()->pluck('type')->all());
        $this->assertEqualsCanonicalizing(['commentaire', 'reponse'], $this->auteur->notifications()->pluck('type')->all());
    }

    public function test_aimer_epingler_modifier_et_supprimer_un_commentaire(): void
    {
        $kofi = $this->membre('kofi');
        $c = $this->actingAs($kofi)->postJson($this->url('/commentaires'), ['texte' => 'Premier'])->json('data.id');
        $d = $this->actingAs($kofi)->postJson($this->url('/commentaires'), ['texte' => 'Deuxième'])->json('data.id');

        $this->actingAs($this->auteur)->putJson("/api/v1/commentaires/{$c}/jaime")->assertJsonPath('total', 1);
        $this->actingAs($this->auteur)->getJson($this->url('/commentaires'))->assertJsonPath('data.1.moi.jaime', true);

        // L'auteur de la publication épingle : l'épinglé passe en tête.
        $this->actingAs($kofi)->postJson("/api/v1/commentaires/{$c}/epingle")->assertNotFound();
        $this->actingAs($this->auteur)->postJson("/api/v1/commentaires/{$c}/epingle")->assertJsonPath('epingle', true);
        $this->getJson($this->url('/commentaires'))->assertJsonPath('data.0.id', $c)->assertJsonPath('data.0.epingle', true);

        $this->actingAs($this->auteur)->patchJson("/api/v1/commentaires/{$c}", ['texte' => 'Pas à moi'])->assertNotFound();
        $this->actingAs($kofi)->patchJson("/api/v1/commentaires/{$c}", ['texte' => 'Premier, corrigé'])->assertOk()->assertJsonPath('data.texte', 'Premier, corrigé');
        // Une heure plus tard, il ne se modifie plus (il se supprime encore).
        $this->travel(61)->minutes();
        $this->actingAs($kofi)->patchJson("/api/v1/commentaires/{$c}", ['texte' => 'Trop tard'])->assertStatus(422)
            ->assertJsonPath('message', 'Un commentaire ne se modifie plus après 1 h. Vous pouvez le supprimer.');
        $this->travelBack();

        // L'auteur de la publication peut retirer un commentaire chez lui.
        $this->actingAs($this->auteur)->deleteJson("/api/v1/commentaires/{$d}")->assertNoContent();
        $this->assertSame(1, $this->photo->refresh()->nombre_commentaires);
        $this->actingAs($this->membre('ola'))->deleteJson("/api/v1/commentaires/{$c}")->assertNotFound();
    }

    public function test_suivre_un_createur_et_ses_reels_dans_abonnements(): void
    {
        $kofi = $this->membre('kofi');
        $reel = Contenu::factory()->complet()->reel()->create(['lieu_id' => $this->lieu->id, 'utilisateur_id' => $this->auteur->id]);
        Contenu::factory()->complet()->reel()->create(['lieu_id' => $this->lieu->id]);

        $this->actingAs($kofi)->putJson('/api/v1/utilisateurs/@aicha.k/abonnement')->assertOk()->assertJsonPath('abonnes', 1);
        $this->actingAs($kofi)->putJson('/api/v1/utilisateurs/kofi/abonnement')->assertStatus(422);
        $this->actingAs($kofi)->getJson('/api/v1/utilisateurs/aicha.k')->assertJsonPath('data.moi.abonne', true)->assertJsonPath('data.compteurs.abonnes', 1);
        $this->actingAs($kofi)->getJson('/api/v1/moi/abonnements')->assertJsonPath('data.0.nom_utilisateur', 'aicha.k');
        $this->actingAs($kofi)->getJson('/api/v1/reels?abonnements=1')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $reel->ulid);
        $this->assertSame('abonne', $this->auteur->notifications()->value('type'));

        $this->actingAs($kofi)->deleteJson('/api/v1/utilisateurs/aicha.k/abonnement')->assertJsonPath('abonnes', 0);
        $this->actingAs($kofi)->getJson('/api/v1/reels?abonnements=1')->assertJsonCount(0, 'data');
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/reels?abonnements=1')->assertUnauthorized();
    }

    public function test_bloquer_cache_ses_publications_et_ses_commentaires(): void
    {
        $kofi = $this->membre('kofi');
        $this->actingAs($this->auteur)->postJson($this->url('/commentaires'), ['texte' => 'Bienvenue']);
        $this->actingAs($kofi)->putJson('/api/v1/utilisateurs/aicha.k/abonnement');

        $this->actingAs($kofi)->putJson('/api/v1/utilisateurs/aicha.k/blocage')->assertOk()->assertJsonPath('bloque', true);
        $this->assertSame(0, $this->auteur->refresh()->nombre_abonnes);
        $this->actingAs($kofi)->getJson('/api/v1/lieux/ouidah/contenus')->assertJsonCount(0, 'data');
        $this->actingAs($kofi)->getJson($this->url('/commentaires'))->assertJsonCount(0, 'data');
        $this->actingAs($kofi)->putJson('/api/v1/utilisateurs/aicha.k/abonnement')->assertStatus(422);
        // Pour celle qu'il a bloquée, son profil n'existe plus.
        $this->actingAs($this->auteur)->getJson('/api/v1/utilisateurs/kofi')->assertNotFound();

        $this->actingAs($kofi)->getJson('/api/v1/moi/blocages')->assertJsonCount(1, 'data')->assertJsonPath('data.0.nom_utilisateur', 'aicha.k');
        $this->actingAs($kofi)->deleteJson('/api/v1/utilisateurs/aicha.k/blocage')->assertJsonPath('bloque', false);
        $this->actingAs($kofi)->getJson('/api/v1/moi/blocages')->assertJsonCount(0, 'data');
        $this->actingAs($kofi)->getJson('/api/v1/lieux/ouidah/contenus')->assertJsonCount(1, 'data');
    }

    public function test_les_collections_secretes_ou_non(): void
    {
        $kofi = $this->membre('kofi');
        $plages = $this->actingAs($kofi)->postJson('/api/v1/collections', ['nom' => 'Plages', 'secrete' => true])->assertCreated()->json('data.id');
        $this->actingAs($kofi)->postJson('/api/v1/collections', ['nom' => 'Plages'])->assertStatus(422)->assertJsonPath('message', 'Vous avez déjà une collection « Plages ».');

        $this->actingAs($kofi)->putJson("/api/v1/collections/{$plages}/contenus/{$this->photo->ulid}")->assertOk()
            ->assertJsonPath('collection.nombre_contenus', 1)->assertJsonCount(1, 'collection.couverture');
        $this->actingAs($kofi)->putJson("/api/v1/collections/{$plages}/contenus/{$this->photo->ulid}")->assertJsonPath('collection.nombre_contenus', 1);
        $this->assertSame(1, $this->photo->refresh()->nombre_enregistrements);
        $this->actingAs($kofi)->getJson($this->url())->assertJsonPath('data.moi.enregistre', true);

        // Secrète : elle n'existe que pour Kofi.
        $this->actingAs($kofi)->getJson("/api/v1/collections/{$plages}/contenus")->assertOk()->assertJsonCount(1, 'data');
        $this->actingAs($this->auteur)->getJson("/api/v1/collections/{$plages}/contenus")->assertNotFound();
        $this->actingAs($this->auteur)->getJson('/api/v1/utilisateurs/kofi/collections')->assertJsonCount(0, 'data');
        $this->actingAs($this->auteur)->putJson("/api/v1/collections/{$plages}/contenus/{$this->photo->ulid}")->assertNotFound();

        $this->actingAs($kofi)->patchJson("/api/v1/collections/{$plages}", ['secrete' => false, 'nom' => 'Mes plages'])->assertJsonPath('data.nom', 'Mes plages');
        $this->actingAs($this->auteur)->getJson('/api/v1/utilisateurs/kofi/collections')->assertJsonCount(1, 'data');

        $this->actingAs($kofi)->deleteJson("/api/v1/collections/{$plages}/contenus/{$this->photo->ulid}")->assertJsonPath('collection.nombre_contenus', 0);
        $this->actingAs($kofi)->deleteJson("/api/v1/collections/{$plages}")->assertNoContent();
        $this->actingAs($kofi)->getJson('/api/v1/collections')->assertJsonCount(0, 'data');
    }

    public function test_partager_et_signaler(): void
    {
        $this->postJson($this->url('/partage'))->assertOk()->assertJsonPath('partages', 1);

        $kofi = $this->membre('kofi');
        $this->actingAs($kofi)->postJson('/api/v1/signalements', ['cible' => 'contenu', 'id' => $this->photo->ulid, 'motif' => 'Image générée ou retouchée par IA'])
            ->assertCreated()->assertJsonPath('message', 'Merci. L’équipe regarde votre signalement sous 24 h. La personne visée ne saura pas qui l’a fait.');
        // Une seule fois par membre et par cible.
        $this->actingAs($kofi)->postJson('/api/v1/signalements', ['cible' => 'contenu', 'id' => $this->photo->ulid, 'motif' => 'Spam ou arnaque'])->assertCreated();
        $this->assertDatabaseCount('signalements', 1);
        $this->actingAs($kofi)->postJson('/api/v1/signalements', ['cible' => 'utilisateur', 'id' => '@aicha.k', 'motif' => 'Spam ou arnaque'])->assertCreated();
        $this->actingAs($kofi)->postJson('/api/v1/signalements', ['cible' => 'lieu', 'id' => 'x', 'motif' => 'x'])->assertStatus(422);
    }

    public function test_une_publication_refusee_ou_publiee_est_annoncee_a_son_auteur(): void
    {
        $c = Contenu::factory()->brouillon()->create(['lieu_id' => $this->lieu->id, 'utilisateur_id' => $this->auteur->id]);
        $this->auteur->notify(new Activite('publiee', 'Votre publication est en ligne, vérifiée.', null, $c));

        $this->actingAs($this->auteur)->getJson('/api/v1/notifications')->assertJsonPath('data.0.genre', 'publiee')->assertJsonPath('data.0.acteur', null);
    }

    public function test_une_notification_dit_le_vrai_badge_et_se_supprime(): void
    {
        $this->photo->update(['badge' => 'declaree']);
        // Une ancienne notification disait « vérifiée » à tort : le texte suit le vrai badge.
        $this->auteur->notify(new Activite('publiee', 'Votre publication est en ligne, vérifiée.', null, $this->photo));
        $n = $this->actingAs($this->auteur)->getJson('/api/v1/notifications')->assertOk()
            ->assertJsonPath('data.0.texte', 'Votre publication est en ligne. Informations déclarées.')
            ->assertJsonPath('data.0.contenu.id', $this->photo->ulid)
            ->assertJsonPath('data.0.contenu.badge', 'declaree')
            ->assertJsonPath('data.0.contenu.lieu', 'ouidah');

        // Vérifiée ensuite par l'équipe : la notification le dit.
        $this->photo->update(['badge' => 'verifiee']);
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.0.contenu.badge', 'verifiee')
            ->assertJsonPath('data.0.texte', 'Votre publication est en ligne. Capture vérifiée.');

        // Supprimée ensuite : la notification ne dit plus qu'elle est en ligne.
        $this->photo->delete();
        $this->getJson('/api/v1/notifications')->assertJsonPath('data.0.contenu', null)
            ->assertJsonPath('data.0.texte', 'Cette publication a été supprimée.');

        $this->deleteJson('/api/v1/notifications/'.$n->json('data.0.id'))->assertOk()->assertJsonPath('non_lues', 0);
        $this->getJson('/api/v1/notifications')->assertJsonCount(0, 'data');
    }

    public function test_l_accueil_dit_ce_que_j_ai_deja_aime(): void
    {
        $kofi = $this->membre('kofi');
        $this->actingAs($kofi)->putJson($this->url('/reaction'), ['type' => 'coeur'])->assertOk();
        // La page de l'accueil est gardée en cache pour tous : ma part s'y ajoute à chaque fois.
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/flux/decouverte')->assertOk()->assertJsonMissingPath('data.0.photos.0.moi');
        $this->actingAs($kofi)->getJson('/api/v1/flux/decouverte')->assertJsonPath('data.0.photos.0.moi.reaction', 'coeur');
        $this->app['auth']->forgetGuards();
        $this->actingAs($this->membre('ola'))->getJson('/api/v1/flux/decouverte')->assertJsonPath('data.0.photos.0.moi.reaction', null);
        $this->actingAs($kofi)->getJson('/api/v1/lieux/ouidah')->assertJsonPath('data.photos.0.moi.reaction', 'coeur');
    }
}
