<?php

namespace Tests\Feature;

use App\Models\Contenu;
use App\Models\Envoi;
use App\Models\Lieu;
use App\Models\ModeleTelephone;
use App\Models\Pays;
use App\Models\Son;
use App\Models\Utilisateur;
use App\Models\Ville;
use App\Services\Contenus\DetecteurIa;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** Lot 3 : publier une photo ou un reel, par morceaux, jusqu'à la décision (E12 à E16). */
class PublicationTest extends TestCase
{
    use RefreshDatabase;

    private Utilisateur $membre;

    private string $jeton;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
        $this->membre = Utilisateur::factory()->create();
        $this->jeton = $this->membre->createToken('t')->plainTextToken;
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $ville = Ville::create(['pays_id' => $benin->id, 'nom' => 'Ouidah', 'region' => 'Atlantique']);
        Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'ville_id' => $ville->id, 'type' => 'Plages', 'latitude' => 6.3256, 'longitude' => 2.0886]);
    }

    private function auth(?string $jeton = null): array
    {
        return ['Authorization' => 'Bearer '.($jeton ?? $this->jeton)];
    }

    /** Une vraie image : JPEG ou WebP, d'une taille donnée, avec un texte glissé dans un commentaire. */
    private function image(int $l = 3000, int $h = 4000, string $format = 'jpg', string $commentaire = ''): string
    {
        $im = imagecreatetruecolor($l, $h);
        imagefilledrectangle($im, 0, 0, $l, $h, imagecolorallocate($im, 30, 120, 200));
        ob_start();
        $format === 'webp' ? imagewebp($im, null, 70) : imagejpeg($im, null, 70);
        $octets = (string) ob_get_clean();
        imagedestroy($im);
        if ($commentaire !== '' && $format === 'jpg') {
            // Un segment COM juste après le début du JPEG, comme le ferait un logiciel.
            $octets = "\xFF\xD8\xFF\xFE".pack('n', strlen($commentaire) + 2).$commentaire.substr($octets, 2);
        }

        return $octets;
    }

    private function annoncer(string $apercu, string $original, array $plus = []): array
    {
        $r = $this->postJson('/api/v1/contenus', array_replace_recursive([
            'type' => 'photo',
            'legende' => 'Le ponton au lever du jour.',
            'capture' => [
                'source' => 'appareil',
                'marque' => 'Tecno',
                'modele' => 'Camon 50 Pro',
                'prise_le' => now()->subHour()->toIso8601String(),
                'latitude' => 6.3262,
                'longitude' => 2.0893,
                'origines' => ['modele' => 'appareil', 'date' => 'appareil', 'position' => 'appareil'],
            ],
            'fichiers' => [
                'apercu' => ['taille' => strlen($apercu), 'type' => 'image/webp', 'empreinte' => hash('sha256', $apercu)],
                'original' => ['taille' => strlen($original), 'type' => 'image/jpeg', 'empreinte' => hash('sha256', $original)],
            ],
        ], $plus), $this->auth());
        $r->assertCreated();

        return $r->json();
    }

    /** Envoie un fichier en morceaux de $taille octets, puis le termine. */
    private function envoyer(string $id, string $octets, int $taille = 64 * 1024): void
    {
        foreach (str_split($octets, $taille) as $i => $morceau) {
            $this->call('PATCH', "/api/v1/envois/{$id}", [], [], [], $this->serveur(['Upload-Offset' => (string) ($i * $taille)]), $morceau)->assertNoContent();
        }
        $this->postJson("/api/v1/envois/{$id}/terminer", [], $this->auth())->assertOk();
    }

    private function serveur(array $entetes, ?string $jeton = null): array
    {
        $s = ['HTTP_AUTHORIZATION' => 'Bearer '.($jeton ?? $this->jeton), 'CONTENT_TYPE' => 'application/offset+octet-stream', 'HTTP_ACCEPT' => 'application/json'];
        foreach ($entetes as $k => $v) {
            $s['HTTP_'.strtoupper(str_replace('-', '_', $k))] = $v;
        }

        return $s;
    }

    public function test_une_photo_prise_avec_discover_est_publiee_verifiee(): void
    {
        $apercu = $this->image(1620, 2160, 'webp');
        $original = $this->image();
        $a = $this->annoncer($apercu, $original);
        $this->assertSame('brouillon', $a['contenu']['statut']);
        $this->assertSame('ouidah', $a['contenu']['lieu']['id']);
        $this->assertSame('Tecno Camon 50 Pro', $a['contenu']['capture']['telephone']);

        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $c = Contenu::where('ulid', $a['contenu']['id'])->first();
        $this->assertSame('publie', $c->statut->value);
        $this->assertSame('verifiee', $c->badge->value);
        $this->assertSame(1, Lieu::where('slug', 'ouidah')->value('nombre_contenus'));

        // L'original arrive ensuite : la 2 160 et la 3 840 px se font à partir de lui.
        $this->envoyer($a['envois']['original']['id'], $original, 512 * 1024);
        $this->assertEqualsCanonicalizing(['flou', '480', '1080', '2160', '3840'], $c->variantes()->pluck('usage')->map->value->all());
        $petite = Storage::disk('public')->path($c->variantes()->where('usage', '480')->value('chemin'));
        $this->assertSame(['image/webp', 360, 480], [mime_content_type($petite), getimagesize($petite)[0], getimagesize($petite)[1]]);
        // Vérifié, l'original reste sur le téléphone : le serveur n'en garde que l'empreinte (les
        // doublons), et son dossier de travail est vide.
        Storage::disk('local')->assertMissing("contenus/{$c->ulid}");
        $this->assertDatabaseHas('fichiers_originaux', ['contenu_id' => $c->id, 'empreinte_sha256' => hash('sha256', $original), 'chemin' => null]);

        // Publié : visible sans compte, avec ses images.
        $this->app['auth']->forgetGuards();
        $this->getJson("/api/v1/contenus/{$c->ulid}")->assertOk()->assertJsonPath('data.badge', 'verifiee')->assertJsonPath('data.images.480.largeur', 360);
    }

    public function test_une_photo_pour_mon_lifestyle_ne_passe_pas_a_l_accueil(): void
    {
        $apercu = $this->image(1620, 2160, 'webp');
        $a = $this->annoncer($apercu, $this->image(), ['portee' => 'lifestyle']);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $c = Contenu::where('ulid', $a['contenu']['id'])->first();
        $this->assertSame(['publie', 'lifestyle'], [$c->statut->value, $c->portee]);
        // Ni le compte du lieu, ni l'accueil, ni la page du lieu.
        $this->assertSame(0, Lieu::where('slug', 'ouidah')->value('nombre_contenus'));
        $this->getJson('/api/v1/flux/decouverte')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/lieux/ouidah/contenus')->assertJsonCount(0, 'data');
        // Dans mon lifestyle.
        $this->getJson('/api/v1/moi/lifestyle', $this->auth())->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.portee', 'lifestyle')->assertJsonPath('visible', false);
    }

    public function test_une_coupure_puis_la_reprise_au_bon_decalage(): void
    {
        $apercu = $this->image(800, 1000, 'webp');
        $a = $this->annoncer($apercu, $this->image(1200, 1600));
        $id = $a['envois']['apercu']['id'];
        $moitie = intdiv(strlen($apercu), 2);

        $this->call('PATCH', "/api/v1/envois/{$id}", [], [], [], $this->serveur(['Upload-Offset' => '0']), substr($apercu, 0, $moitie))->assertNoContent();
        // La connexion tombe ; l'application redemande où on en est.
        $this->call('HEAD', "/api/v1/envois/{$id}", [], [], [], $this->serveur([]))->assertOk()->assertHeader('Upload-Offset', (string) $moitie);
        // Un morceau qui ne suit pas est refusé.
        $this->call('PATCH', "/api/v1/envois/{$id}", [], [], [], $this->serveur(['Upload-Offset' => '0']), substr($apercu, 0, 10))
            ->assertStatus(409)->assertJsonPath('message', 'Le morceau ne suit pas le précédent.');
        // Terminer trop tôt aussi.
        $this->postJson("/api/v1/envois/{$id}/terminer", [], $this->auth())->assertStatus(409);

        $this->call('PATCH', "/api/v1/envois/{$id}", [], [], [], $this->serveur(['Upload-Offset' => (string) $moitie]), substr($apercu, $moitie))->assertNoContent();
        $this->postJson("/api/v1/envois/{$id}/terminer", [], $this->auth())->assertOk();
        $this->assertSame('publie', Contenu::where('ulid', $a['contenu']['id'])->first()->statut->value);
    }

    public function test_un_fichier_abime_en_route_repart_de_zero(): void
    {
        $apercu = $this->image(400, 500, 'webp');
        $a = $this->annoncer($apercu, $this->image(400, 500));
        $id = $a['envois']['apercu']['id'];
        $abime = substr_replace($apercu, 'XX', 100, 2);

        $this->call('PATCH', "/api/v1/envois/{$id}", [], [], [], $this->serveur(['Upload-Offset' => '0']), $abime)->assertNoContent();
        $this->postJson("/api/v1/envois/{$id}/terminer", [], $this->auth())->assertUnprocessable()->assertJsonPath('erreurs.fichier.0', 'Le fichier est arrivé abîmé. Il va repartir depuis le début.');
        $this->assertSame(0, Envoi::where('ulid', $id)->value('recu'));
    }

    public function test_un_faux_fichier_est_refuse_par_sa_signature(): void
    {
        $faux = '<?php echo "pas une image"; ?>'.str_repeat(' ', 200);
        $a = $this->annoncer($faux, $this->image(400, 500));
        $id = $a['envois']['apercu']['id'];
        $this->call('PATCH', "/api/v1/envois/{$id}", [], [], [], $this->serveur(['Upload-Offset' => '0']), $faux)->assertNoContent();
        $this->postJson("/api/v1/envois/{$id}/terminer", [], $this->auth())->assertUnprocessable()->assertJsonPath('erreurs.fichier.0', 'Ce fichier n’est pas une photo ou une vidéo acceptée.');
    }

    public function test_on_n_envoie_pas_dans_l_envoi_d_un_autre(): void
    {
        $apercu = $this->image(400, 500, 'webp');
        $a = $this->annoncer($apercu, $this->image(400, 500));
        $autre = Utilisateur::factory()->create()->createToken('t')->plainTextToken;
        $this->app['auth']->forgetGuards();

        $this->call('PATCH', "/api/v1/envois/{$a['envois']['apercu']['id']}", [], [], [], $this->serveur(['Upload-Offset' => '0'], $autre), $apercu)->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->deleteJson("/api/v1/contenus/{$a['contenu']['id']}", [], $this->auth($autre))->assertNotFound();
    }

    public function test_une_image_qui_avoue_une_ia_est_refusee(): void
    {
        $apercu = $this->image(400, 500, 'jpg', '<Iptc4xmpExt:DigitalSourceType>http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia</Iptc4xmpExt:DigitalSourceType>');
        $a = $this->annoncer($apercu, $this->image(400, 500), ['fichiers' => ['apercu' => ['type' => 'image/jpeg']]]);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);

        $c = Contenu::where('ulid', $a['contenu']['id'])->first();
        $this->assertSame('refuse', $c->statut->value);
        $this->assertStringContainsString('générée par une IA', $c->motif);
        $this->getJson("/api/v1/contenus/{$c->ulid}", $this->auth())->assertJsonPath('data.motif', $c->motif);
    }

    public function test_sans_telephone_ni_date_il_faut_completer_puis_c_est_declare(): void
    {
        $apercu = $this->image(400, 500, 'webp');
        $a = $this->annoncer($apercu, $this->image(400, 500), ['capture' => ['source' => 'fichier', 'marque' => null, 'modele' => null, 'prise_le' => null]]);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $ulid = $a['contenu']['id'];
        $this->getJson("/api/v1/contenus/{$ulid}", $this->auth())->assertJsonPath('data.statut', 'a_completer')->assertJsonPath('data.manque', ['telephone', 'date']);

        // E15 : le membre indique son téléphone et la date.
        $this->patchJson("/api/v1/contenus/{$ulid}", ['marque' => 'Infinix', 'modele' => 'Note 40', 'prise_le' => now()->subDays(3)->toDateString()], $this->auth())
            ->assertOk()->assertJsonPath('data.statut', 'publie')->assertJsonPath('data.badge', 'declaree')->assertJsonPath('data.capture.telephone', 'Infinix Note 40');

        // En ligne : son auteur la modifie pendant 1 h, puis il ne peut plus que la supprimer.
        $this->patchJson("/api/v1/contenus/{$ulid}", ['titre' => 'Le marché'], $this->auth())->assertOk()->assertJsonPath('data.titre', 'Le marché')
            ->assertJsonPath('data.modifiable_jusqu_au', fn ($d) => $d !== null);
        $this->travel(61)->minutes();
        $this->patchJson("/api/v1/contenus/{$ulid}", ['titre' => 'Trop tard'], $this->auth())->assertStatus(422)
            ->assertJsonPath('message', 'Une publication ne se modifie plus après 1 h. Vous pouvez la supprimer.');
        $this->deleteJson("/api/v1/contenus/{$ulid}", [], $this->auth())->assertNoContent();
    }

    public function test_ce_que_le_fichier_n_a_pas_dit_ne_peut_pas_etre_verifie(): void
    {
        // L'application dit avoir lu l'EXIF, mais l'original n'en a aucune : « déclarées ».
        $apercu = $this->image(400, 500, 'webp');
        $original = $this->image(400, 500);
        $a = $this->annoncer($apercu, $original, ['capture' => ['source' => 'fichier', 'origines' => ['modele' => 'exif', 'date' => 'exif', 'position' => 'exif']]]);
        $this->envoyer($a['envois']['original']['id'], $original);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);

        $this->assertSame('declaree', Contenu::where('ulid', $a['contenu']['id'])->first()->badge->value);
    }

    public function test_une_date_dans_le_futur_est_refusee_des_l_envoi(): void
    {
        $r = $this->actingAs(Utilisateur::factory()->create())
            ->postJson('/api/v1/contenus', ['type' => 'photo', 'capture' => ['source' => 'declaree', 'prise_le' => now()->addDays(5)->toIso8601String()]])
            ->assertStatus(422);
        $this->assertContains('La date de prise ne peut pas être dans le futur.', (array) ($r->json('erreurs')['capture.prise_le'] ?? []));
        $this->assertSame(0, Contenu::count());
    }

    public function test_un_lieu_inconnu_est_cree_depuis_le_nom_donne_par_android(): void
    {
        $a = $this->annoncer('a', 'b', [
            'capture' => ['latitude' => 6.3530, 'longitude' => 2.3820],
            'lieu_nom' => 'Plage de Fidjrossè', 'ville' => 'Cotonou', 'region' => 'Littoral', 'pays' => 'Bénin', 'pays_code' => 'bj',
        ]);
        $this->assertSame('plage-de-fidjrosse', $a['contenu']['lieu']['id']);
        $this->assertSame('Littoral, Bénin', $a['contenu']['lieu']['region']);
    }

    public function test_un_reel_attend_sa_video_et_la_sert(): void
    {
        $affiche = $this->image(1080, 1920, 'webp');
        // Un petit MP4 : l'en-tête « ftyp » suffit à finfo.
        $video = "\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom".str_repeat("\x00", 2048);
        $a = $this->annoncer($affiche, $video, ['type' => 'reel', 'duree' => 24, 'fichiers' => ['original' => ['type' => 'video/mp4']]]);
        $this->envoyer($a['envois']['apercu']['id'], $affiche);
        $ulid = $a['contenu']['id'];
        $this->assertSame('brouillon', Contenu::where('ulid', $ulid)->first()->statut->value);

        $this->envoyer($a['envois']['original']['id'], $video);
        $c = Contenu::where('ulid', $ulid)->first();
        $this->assertSame('publie', $c->statut->value);
        $this->assertEqualsCanonicalizing(['affiche', 'flou', 'video'], $c->variantes()->pluck('usage')->map->value->all());
    }

    public function test_un_reel_avec_une_musique_du_catalogue(): void
    {
        $son = Son::create(['cle' => 'test:allada', 'titre' => 'Allada', 'artiste' => 'Kevin MacLeod', 'categorie' => 'afro', 'duree_ms' => 223_000, 'chemin' => 'sons/allada.m4a', 'debut_conseille_ms' => 40_000, 'licence' => 'CC BY 4.0', 'attribution' => '« Allada » Kevin MacLeod']);
        $affiche = $this->image(1080, 1920, 'webp');
        $video = "\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom".str_repeat("\x00", 2048);
        $a = $this->annoncer($affiche, $video, ['type' => 'reel', 'duree' => 12, 'musique' => ['id' => $son->ulid, 'volume' => 80, 'volume_origine' => 30], 'fichiers' => ['original' => ['type' => 'video/mp4']]]);
        $c = Contenu::where('ulid', $a['contenu']['id'])->first();
        // Sans extrait choisi : le passage proposé par le catalogue.
        $this->assertSame([$son->id, 40_000, 80, 30, 'Allada · Kevin MacLeod'], [$c->son_id, $c->son_debut_ms, $c->son_volume, $c->origine_volume, $c->son]);

        $this->envoyer($a['envois']['apercu']['id'], $affiche);
        $this->envoyer($a['envois']['original']['id'], $video);
        $this->assertSame(1, $son->refresh()->nombre_reels);
        $this->getJson("/api/v1/contenus/{$c->ulid}")->assertJsonPath('data.musique.id', $son->ulid)->assertJsonPath('data.musique.titre', 'Allada');

        // Un son retiré du catalogue ne se choisit plus.
        $son->update(['actif' => false]);
        $this->postJson('/api/v1/contenus', ['type' => 'reel', 'duree' => 5, 'musique' => ['id' => $son->ulid]], $this->auth())->assertUnprocessable()->assertJsonValidationErrors('musique.id', 'erreurs');
    }

    public function test_une_duree_de_plus_de_60_secondes_est_refusee(): void
    {
        $this->postJson('/api/v1/contenus', ['type' => 'reel', 'duree' => 75], $this->auth())->assertUnprocessable()->assertJsonPath('erreurs.duree.0', 'Un reel dure 60 secondes au plus.');
    }

    public function test_la_meme_photo_ne_se_publie_pas_deux_fois(): void
    {
        $apercu = $this->image(400, 500, 'webp');
        $original = $this->image(400, 500);
        $a = $this->annoncer($apercu, $original);
        $this->envoyer($a['envois']['original']['id'], $original);

        $this->postJson('/api/v1/contenus', [
            'type' => 'photo',
            'capture' => ['source' => 'appareil'],
            'fichiers' => [
                'apercu' => ['taille' => 10, 'type' => 'image/webp', 'empreinte' => str_repeat('a', 64)],
                'original' => ['taille' => strlen($original), 'type' => 'image/jpeg', 'empreinte' => hash('sha256', $original)],
            ],
        ], $this->auth())->assertStatus(409)->assertJsonPath('message', 'Cette photo ou cette vidéo est déjà publiée sur Discover.');
    }

    public function test_telecharger_donne_la_plus_grande_taille_quand_l_original_n_est_pas_garde(): void
    {
        $apercu = $this->image(1620, 2160, 'webp');
        $original = $this->image();
        $a = $this->annoncer($apercu, $original);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $this->envoyer($a['envois']['original']['id'], $original, 512 * 1024);

        $r = $this->getJson("/api/v1/contenus/{$a['contenu']['id']}/original")->assertOk()->assertJsonPath('original', false);
        $this->assertStringEndsWith("contenus/{$a['contenu']['id']}/3840.webp", $r->json('url'));
    }

    public function test_un_original_assez_grand_donne_aussi_la_4k_et_on_choisit_la_taille(): void
    {
        $apercu = $this->image(1620, 2160, 'webp');
        $original = $this->image(4000, 5000);
        $a = $this->annoncer($apercu, $original);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $this->envoyer($a['envois']['original']['id'], $original, 512 * 1024);

        $c = Contenu::where('ulid', $a['contenu']['id'])->first();
        $this->assertEqualsCanonicalizing(['flou', '480', '1080', '2160', '3840'], $c->variantes()->pluck('usage')->map->value->all());
        $this->assertSame([3072, 3840], [$c->variantes()->where('usage', '3840')->value('largeur'), $c->variantes()->where('usage', '3840')->value('hauteur')]);

        $id = $a['contenu']['id'];
        $this->assertStringEndsWith("contenus/{$id}/3840.webp", $this->getJson("/api/v1/contenus/{$id}/original")->json('url'));
        $this->assertStringEndsWith("contenus/{$id}/1080.webp", $this->getJson("/api/v1/contenus/{$id}/original?taille=1080")->json('url'));
        $this->assertStringEndsWith("contenus/{$id}/3840.webp", $this->getJson("/api/v1/contenus/{$id}/original?taille=flou")->json('url'));
    }

    public function test_un_contenu_refuse_garde_ses_fichiers_30_jours_puis_plus_rien(): void
    {
        $this->app->instance(DetecteurIa::class, new class extends DetecteurIa
        {
            public function motif(string $chemin): ?string
            {
                return 'marque de provenance d’une image générée par une IA';
            }
        });
        $apercu = $this->image(400, 500, 'webp');
        $a = $this->annoncer($apercu, $this->image(400, 500));
        $this->envoyer($a['envois']['apercu']['id'], $apercu);

        $this->assertSame('refuse', Contenu::where('ulid', $a['contenu']['id'])->value('statut')->value);
        // Le temps d'une seconde vérification, si l'auteur la demande.
        Storage::disk('local')->assertExists("contenus/{$a['contenu']['id']}");

        Contenu::where('ulid', $a['contenu']['id'])->update(['updated_at' => now()->subDays(31)]);
        $this->artisan('usw:purger-envois')->assertSuccessful();
        Storage::disk('local')->assertMissing("contenus/{$a['contenu']['id']}");
    }

    public function test_l_original_garde_par_un_lien_signe_de_10_minutes(): void
    {
        config(['discover.garder_originaux' => true]);
        $apercu = $this->image(400, 500, 'webp');
        $original = $this->image(400, 500);
        $a = $this->annoncer($apercu, $original);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $this->envoyer($a['envois']['original']['id'], $original);

        $url = $this->getJson("/api/v1/contenus/{$a['contenu']['id']}/original")->assertOk()->assertJsonPath('original', true)->json('url');
        Storage::disk('local')->assertMissing("contenus/{$a['contenu']['id']}/apercu.webp");
        $this->get($url)->assertOk()->assertDownload("discover-{$a['contenu']['id']}.jpg");
        $this->get(preg_replace('/signature=[^&]+/', 'signature=faux', $url))->assertForbidden();
        $this->travel(11)->minutes();
        $this->get($url)->assertForbidden();
    }

    public function test_supprimer_son_contenu_efface_ses_fichiers(): void
    {
        $apercu = $this->image(400, 500, 'webp');
        $a = $this->annoncer($apercu, $this->image(400, 500));
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $ulid = $a['contenu']['id'];

        $this->deleteJson("/api/v1/contenus/{$ulid}", [], $this->auth())->assertNoContent();
        $this->assertDatabaseMissing('contenus', ['ulid' => $ulid]);
        Storage::disk('public')->assertMissing("contenus/{$ulid}/480.webp");
        $this->assertSame(0, Lieu::where('slug', 'ouidah')->value('nombre_contenus'));
    }

    public function test_mes_envois_en_cours_puis_le_menage_de_nuit(): void
    {
        $a = $this->annoncer('aperçu', 'original');
        $this->getJson('/api/v1/moi/envois', $this->auth())->assertOk()->assertJsonCount(2, 'data');

        $this->travel(8)->days();
        $this->artisan('usw:purger-envois')->assertSuccessful();
        $this->assertDatabaseMissing('contenus', ['ulid' => $a['contenu']['id']]);
        $this->assertSame(0, Envoi::count());
    }

    public function test_un_nom_seul_devient_un_lieu_sans_position(): void
    {
        $apercu = $this->image(1620, 2160, 'webp');
        $original = $this->image();
        // Un nom seul : un vrai lieu, avec sa pile ; la position de la prise ne se montre pas, ni la carte.
        $a = $this->annoncer($apercu, $original, ['nom_lieu' => 'Chez ma grand-mère']);
        $this->assertSame('chez-ma-grand-mere', $a['contenu']['lieu']['id']);
        $this->assertSame('Chez ma grand-mère', $a['contenu']['lieu']['nom']);
        $this->assertFalse($a['contenu']['lieu']['situe']);
        $this->assertNull($a['contenu']['capture']['latitude']);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $this->envoyer($a['envois']['original']['id'], $original);
        $this->getJson('/api/v1/flux/decouverte')->assertJsonPath('data.0.id', 'chez-ma-grand-mere');
        // Le meme nom, ecrit autrement : le meme lieu.
        $b = $this->annoncer($this->image(1620, 2160, 'webp', 'c'), $this->image(3000, 4000, 'jpg', 'c'), ['nom_lieu' => 'chez ma GRAND-MERE']);
        $this->assertSame('chez-ma-grand-mere', $b['contenu']['lieu']['id']);
        // Sans position : ni sur la carte, ni « Y aller » (situe faux).
        $this->assertNotContains('chez-ma-grand-mere', array_column($this->getJson('/api/v1/carte?nord=90&sud=-90&est=180&ouest=-180')->json('data'), 'id'));
    }

    public function test_sans_lieu_la_photo_est_publiee_dans_la_pile_sans_lieu(): void
    {
        $apercu = $this->image(1620, 2160, 'webp');
        $original = $this->image();
        // Aucun lieu (un nom vide) : la position de la prise ne se montre pas, la photo n'est pas sur la carte.
        $a = $this->annoncer($apercu, $original, ['nom_lieu' => '']);
        $this->assertSame('sans-lieu', $a['contenu']['lieu']['id']);
        $this->assertFalse($a['contenu']['lieu']['situe']);
        $this->assertNull($a['contenu']['capture']['latitude']);
        $this->envoyer($a['envois']['apercu']['id'], $apercu);
        $this->envoyer($a['envois']['original']['id'], $original);
        $ulid = $a['contenu']['id'];
        $this->getJson("/api/v1/contenus/{$ulid}", $this->auth())->assertJsonPath('data.statut', 'publie');

        // La pile « Sans lieu » vient en bas de l'accueil, après les vrais lieux.
        $autre = $this->annoncer($this->image(1620, 2160, 'webp', 'b'), $this->image(3000, 4000, 'jpg', 'b'));
        $this->envoyer($autre['envois']['apercu']['id'], $this->image(1620, 2160, 'webp', 'b'));
        $this->envoyer($autre['envois']['original']['id'], $this->image(3000, 4000, 'jpg', 'b'));
        $decouverte = $this->getJson('/api/v1/flux/decouverte')->json('data');
        $this->assertSame(['ouidah', 'sans-lieu'], array_column($decouverte, 'id'));

        // Ni la pile ni les photos du lieu, chargées sans la relation, ne trahissent la position.
        $this->assertNull($decouverte[1]['photos'][0]['capture']['latitude']);
        $this->assertSame($ulid, $this->getJson('/api/v1/lieux/sans-lieu/contenus')->json('data.0.id'));
        $this->assertNull($this->getJson('/api/v1/lieux/sans-lieu/contenus')->json('data.0.capture.latitude'));
        $this->assertNull($this->getJson('/api/v1/lieux/sans-lieu')->json('data.photos.0.capture.latitude'));
        $this->assertSame(['ouidah'], array_column($this->getJson('/api/v1/carte?nord=90&sud=-90&est=180&ouest=-180')->json('data'), 'id'));
    }

    public function test_un_point_pose_sur_la_carte_garde_sa_position_et_son_nom(): void
    {
        $apercu = $this->image(1620, 2160, 'webp');
        $original = $this->image();
        $a = $this->annoncer($apercu, $original, [
            'capture' => ['latitude' => null, 'longitude' => null],
            'lieu_latitude' => 6.4172, 'lieu_longitude' => 2.3423, 'lieu_nom' => 'IFRI',
            'ville' => 'Abomey-Calavi', 'pays' => 'Bénin', 'pays_code' => 'BJ',
        ]);
        $this->assertSame('ifri', $a['contenu']['lieu']['id']);
        $this->assertTrue($a['contenu']['lieu']['situe']);
        $this->assertSame(6.4172, Lieu::where('slug', 'ifri')->value('latitude'));
    }

    public function test_un_point_pose_a_un_kilometre_d_un_lieu_connu_cree_son_propre_lieu(): void
    {
        // Le Ponton est à environ 1 km : la position de la prise l'aurait rejoint, pas un point posé.
        $a = $this->annoncer($this->image(1620, 2160, 'webp'), $this->image(), [
            'capture' => ['latitude' => null, 'longitude' => null],
            'lieu_latitude' => 6.3346, 'lieu_longitude' => 2.0886, 'lieu_nom' => 'Chez Clarisse',
        ]);
        $this->assertSame('chez-clarisse', $a['contenu']['lieu']['id']);
    }

    public function test_chercher_un_lieu_discover_puis_google(): void
    {
        config(['services.google_places.cle' => 'cle-test']);
        Http::fake([
            'places.googleapis.com/v1/places:autocomplete' => Http::response(['suggestions' => [
                ['placePrediction' => ['placeId' => 'g-ifri', 'structuredFormat' => ['mainText' => ['text' => 'IFRI'], 'secondaryText' => ['text' => 'Abomey-Calavi, Bénin']]]],
            ]]),
            'places.googleapis.com/v1/places/g-ifri*' => Http::response([
                'id' => 'g-ifri', 'displayName' => ['text' => 'IFRI'], 'location' => ['latitude' => 6.4172, 'longitude' => 2.3423],
                'addressComponents' => [
                    ['longText' => 'Abomey-Calavi', 'shortText' => 'Abomey-Calavi', 'types' => ['locality']],
                    ['longText' => 'Bénin', 'shortText' => 'BJ', 'types' => ['country']],
                ],
            ]),
        ]);
        $this->getJson('/api/v1/lieux/suggestions?q=ponton', $this->auth())->assertOk()->assertJsonPath('lieux.0.id', 'ouidah');
        $this->getJson('/api/v1/lieux/suggestions?q=uac ifri', $this->auth())->assertOk()->assertJsonPath('google.0.id', 'g-ifri');
        $this->postJson('/api/v1/lieux/google', ['id' => 'g-ifri'], $this->auth())->assertSuccessful()
            ->assertJsonPath('data.id', 'ifri')->assertJsonPath('data.ville', 'Abomey-Calavi');
        // Aller le voir sur la carte ne crée rien de plus.
        $this->getJson('/api/v1/lieux/google/g-ifri', $this->auth())->assertOk()
            ->assertJsonPath('data.nom', 'IFRI')->assertJsonPath('data.latitude', 6.4172);
        // Le même lieu de Google, une seconde fois : le même lieu de Discover.
        $this->postJson('/api/v1/lieux/google', ['id' => 'g-ifri'], $this->auth())->assertJsonPath('data.id', 'ifri');
        $this->assertSame(1, Lieu::where('nom', 'IFRI')->count());
    }

    public function test_une_panne_de_google_ne_se_garde_pas(): void
    {
        config(['services.google_places.cle' => 'cle-test']);
        Http::fake(['places.googleapis.com/v1/places:autocomplete' => Http::sequence()
            ->push([], 503)
            ->push(['suggestions' => [['placePrediction' => ['placeId' => 'g-ifri', 'text' => ['text' => 'IFRI']]]]]),
        ]);
        $this->getJson('/api/v1/lieux/suggestions?q=ifri', $this->auth())->assertOk()->assertJsonPath('google', []);
        $this->getJson('/api/v1/lieux/suggestions?q=ifri', $this->auth())->assertJsonPath('google.0.id', 'g-ifri');
    }

    public function test_un_telephone_choisi_sans_sa_marque_rejoint_le_modele_existant(): void
    {
        $apple = ModeleTelephone::create(['marque' => 'Apple', 'nom' => 'iPhone 13']);
        $a = $this->annoncer($this->image(1620, 2160, 'webp'), $this->image(), ['capture' => ['marque' => 'iPhone', 'modele' => '13']]);
        $this->assertSame($apple->id, Contenu::where('ulid', $a['contenu']['id'])->first()->capture->modele_telephone_id);
        $this->assertSame(1, ModeleTelephone::where('nom', 'like', '%13%')->count());
    }
}
