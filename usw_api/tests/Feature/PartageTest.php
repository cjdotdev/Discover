<?php

namespace Tests\Feature;

use App\Models\Collection;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Pays;
use App\Models\Utilisateur;
use App\Models\Ville;
use App\Services\Compte\Comptes;
use App\Support\Medias;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PartageTest extends TestCase
{
    use RefreshDatabase;

    private function lieu(): Lieu
    {
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $ville = Ville::create(['pays_id' => $benin->id, 'nom' => 'Ouidah', 'region' => 'Atlantique']);

        return Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'ville_id' => $ville->id, 'type' => 'Plages', 'latitude' => 6.3256, 'longitude' => 2.0886]);
    }

    public function test_un_lieu_partage_donne_son_apercu_et_ouvre_l_application(): void
    {
        $lieu = $this->lieu();
        Contenu::factory()->complet()->create(['lieu_id' => $lieu->id]);

        $this->get('/l/ouidah')->assertOk()
            ->assertSee('<meta property="og:title" content="Ponton de Ouidah">', false)
            ->assertSee('property="og:image"', false)
            ->assertSee('<link rel="canonical" href="https://discover.simeonamoussou.com/l/ouidah">', false)
            ->assertSee('package=bj.usw', false)
            ->assertSee('support@discover.simeonamoussou.com');
        $this->get('/l/inconnu')->assertNotFound();
    }

    public function test_une_photo_publiee_se_partage_pas_un_brouillon(): void
    {
        $lieu = $this->lieu();
        $c = Contenu::factory()->complet()->create(['lieu_id' => $lieu->id, 'legende' => 'Le soir sur la lagune']);
        $brouillon = Contenu::factory()->brouillon()->create(['lieu_id' => $lieu->id]);

        $this->get("/p/{$c->ulid}")->assertOk()->assertSee('Le soir sur la lagune')->assertSee('@'.$c->auteur->nom_utilisateur);
        $this->get("/p/{$brouillon->ulid}")->assertNotFound();
    }

    public function test_un_createur_et_une_collection_publique_mais_pas_secrete(): void
    {
        $u = Utilisateur::factory()->create(['nom_affiche' => 'Simeon']);
        $publique = Collection::create(['utilisateur_id' => $u->id, 'nom' => 'Plages du Bénin', 'secrete' => false]);
        $secrete = Collection::create(['utilisateur_id' => $u->id, 'nom' => 'À revoir', 'secrete' => true]);

        $this->get('/@'.$u->nom_utilisateur)->assertOk()->assertSee('<meta property="og:title" content="Simeon">', false);
        $this->get("/c/{$publique->ulid}")->assertOk()->assertSee('Plages du Bénin');
        $this->get("/c/{$secrete->ulid}")->assertNotFound();

        $u->forceFill(['suspendu_le' => now()])->save();
        $this->get('/@'.$u->nom_utilisateur)->assertNotFound();
    }

    public function test_un_createur_montre_sa_photo_de_profil_et_l_apercu_la_donne_en_jpeg(): void
    {
        Storage::fake(config('discover.medias'));
        $u = Utilisateur::factory()->create(['nom_affiche' => 'Siméon Céphas']);

        // Sans photo : ses initiales, et pas d'image d'aperçu inventée.
        $this->get('/@'.$u->nom_utilisateur)->assertOk()->assertSee('>SC</div>', false)->assertDontSee('og:image', false);

        app(Comptes::class)->changerAvatar($u, UploadedFile::fake()->image('moi.jpg', 800, 600));
        $u->refresh();
        $apercu = 'https://discover.simeonamoussou.com/apercu/'.substr($u->avatar, 0, -5).'.jpg';
        $this->get('/@'.$u->nom_utilisateur)->assertOk()
            ->assertSee('class="avatar" src="'.Medias::public()->url($u->avatar).'"', false)
            ->assertSee('<meta property="og:image" content="'.$apercu.'">', false)
            ->assertSee('<meta property="og:image:width" content="512">', false);

        $r = $this->get('/apercu/'.substr($u->avatar, 0, -5).'.jpg')->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $this->assertSame("\xFF\xD8", substr($r->getContent(), 0, 2));
        Storage::disk(config('discover.medias'))->assertExists(substr($u->avatar, 0, -5).'.jpg');
        $this->get('/apercu/avatars/'.$u->ulid.'-1.jpg')->assertNotFound();
        $this->get('/apercu/autre/chose.jpg')->assertNotFound();

        // Une nouvelle photo : l'ancienne et son aperçu partent.
        $ancien = $u->avatar;
        $this->travel(2)->seconds();
        app(Comptes::class)->changerAvatar($u, UploadedFile::fake()->image('moi2.jpg', 600, 600));
        Storage::disk(config('discover.medias'))->assertMissing($ancien);
        Storage::disk(config('discover.medias'))->assertMissing(substr($ancien, 0, -5).'.jpg');
    }

    public function test_android_ouvre_les_liens_dans_l_application_signee(): void
    {
        $this->getJson('/.well-known/assetlinks.json')->assertOk()
            ->assertJsonPath('0.target.package_name', 'bj.usw')
            ->assertJsonPath('0.target.sha256_cert_fingerprints.0', '05:88:E6:08:45:8D:90:F7:CA:99:1F:28:E9:8B:04:76:7F:4E:47:90:9B:25:F5:1E:CF:D7:E7:0A:94:D9:37:CF');
    }
}
