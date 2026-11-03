<?php

namespace Tests\Feature;

use App\Mail\AdresseChangee;
use App\Mail\CodeParEmail;
use App\Models\CodeEmail;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Services\Compte\VerificateurJetonGoogle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/** Lot 1 : les scénarios du compte, sans mot de passe (écrans E01, E02, E36). */
class CompteTest extends TestCase
{
    use RefreshDatabase;

    private ?string $dernierCode = null;

    /** Le défi du dernier code demandé : seul ce « téléphone » peut essayer le code. */
    private ?string $defi = null;

    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
    }

    private function demander(string $email, ?string $defi = null): TestResponse
    {
        $r = $this->postJson('/api/v1/auth/code/envoyer', array_filter(['email' => $email, 'defi' => $defi]));
        $this->defi = $r->json('defi') ?? $this->defi;

        return $r;
    }

    private function essayer(array $donnees): TestResponse
    {
        return $this->postJson('/api/v1/auth/code', $donnees + ['defi' => $this->defi]);
    }

    /** Le code du dernier e-mail envoyé à cette adresse. */
    private function codeRecu(string $email): string
    {
        $code = null;
        Mail::assertSent(CodeParEmail::class, function (CodeParEmail $m) use ($email, &$code) {
            if ($m->hasTo($email)) {
                $code = $m->code;
            }

            return true;
        });

        return $code;
    }

    /** Demander un code, puis le donner : la seule façon d'entrer avec un e-mail. */
    private function entrer(string $email, ?string $appareil = null)
    {
        $this->demander($email)->assertOk();

        return $this->essayer(['email' => $email, 'code' => $this->codeRecu(mb_strtolower(trim($email))), 'appareil' => $appareil]);
    }

    public function test_une_adresse_inconnue_cree_le_compte_avec_le_code(): void
    {
        $this->demander(' Akouavi@Gmail.com ')
            ->assertOk()->assertJsonPath('message', 'Un code à 6 chiffres a été envoyé à akouavi@gmail.com.');
        $code = $this->codeRecu('akouavi@gmail.com');
        // Rien n'est créé avant le bon code.
        $this->assertSame(0, Utilisateur::count());

        $this->essayer(['email' => 'akouavi@gmail.com', 'code' => $code, 'appareil' => 'Tecno Camon 50 Pro'])
            ->assertCreated()
            ->assertJsonStructure(['jeton', 'nouveau', 'utilisateur' => ['id', 'email', 'nom_utilisateur', 'profil_complete']])
            ->assertJsonPath('nouveau', true)
            // Le nom de départ ne dit rien de l'adresse : le membre choisit le sien en complétant son profil.
            ->assertJsonPath('utilisateur.nom_utilisateur', fn ($nom) => preg_match('/^membre\d{5}$/', $nom) === 1)
            ->assertJsonPath('utilisateur.profil_complete', false);

        $this->assertNotNull(Utilisateur::where('email', 'akouavi@gmail.com')->value('email_verifie_le'));
        $this->assertDatabaseMissing('codes_email', ['code_hache' => $code]);
    }

    public function test_une_adresse_inscrite_entre_avec_le_code_sans_rien_dire_avant(): void
    {
        $u = Utilisateur::factory()->create(['email' => 'akouavi@gmail.com', 'nom_affiche' => 'Akouavi K.']);

        // La réponse à l'envoi est la même qu'une adresse inconnue.
        $envoi = $this->demander('akouavi@gmail.com')->assertOk();
        $this->assertStringNotContainsString('Akouavi K.', $envoi->getContent());

        $this->essayer(['email' => 'akouavi@gmail.com', 'code' => $this->codeRecu('akouavi@gmail.com')])
            ->assertOk()
            ->assertJsonPath('nouveau', false)
            ->assertJsonPath('utilisateur.id', $u->ulid);
        $this->assertSame(1, Utilisateur::count());
    }

    public function test_aucun_mot_de_passe_n_existe_plus(): void
    {
        $this->postJson('/api/v1/auth/connexion', ['email' => 'a@b.co', 'mot_de_passe' => 'lagune2026'])->assertNotFound();
        $this->postJson('/api/v1/auth/inscription', ['email' => 'a@b.co', 'mot_de_passe' => 'lagune2026'])->assertNotFound();
        $this->postJson('/api/v1/auth/oubli', ['email' => 'a@b.co'])->assertNotFound();
        $this->assertFalse(Schema::hasColumn('utilisateurs', 'mot_de_passe'));
    }

    public function test_un_code_faux_dit_combien_d_essais_il_reste_puis_s_epuise(): void
    {
        $this->demander('a@b.co');
        $bon = $this->codeRecu('a@b.co');
        $faux = $bon === '111111' ? '222222' : '111111';

        $this->essayer(['email' => 'a@b.co', 'code' => $faux])
            ->assertStatus(422)->assertJsonPath('erreurs.code.0', 'Code incorrect. Encore 4 essais.');
        for ($i = 0; $i < 4; $i++) {
            $this->essayer(['email' => 'a@b.co', 'code' => $faux]);
        }
        // Même le bon code ne passe plus : il faut en demander un autre.
        $this->essayer(['email' => 'a@b.co', 'code' => $bon])
            ->assertStatus(422)->assertJsonPath('erreurs.code.0', 'Trop d’essais : demandez un nouveau code.');
    }

    public function test_un_autre_qui_tape_mon_adresse_ne_bloque_pas_mon_code(): void
    {
        $this->demander('a@b.co');
        $mien = $this->defi;
        $bon = $this->codeRecu('a@b.co');
        $faux = $bon === '111111' ? '222222' : '111111';

        // Un autre téléphone (une autre IP) : il demande un code et essaie des codes faux.
        $this->withServerVariables(['REMOTE_ADDR' => '10.9.9.9']);
        $this->postJson('/api/v1/auth/code/envoyer', ['email' => 'a@b.co'])->assertOk();
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/code', ['email' => 'a@b.co', 'code' => $faux, 'defi' => str_repeat('x', 40)])->assertStatus(422);
        }
        $this->postJson('/api/v1/auth/code', ['email' => 'a@b.co', 'code' => $bon])->assertStatus(422);

        // Mon code, avec mon défi, passe toujours.
        $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.1']);
        $this->postJson('/api/v1/auth/code', ['email' => 'a@b.co', 'code' => $bon, 'defi' => $mien])->assertCreated();
    }

    public function test_un_code_expire_apres_10_minutes(): void
    {
        $this->demander('a@b.co');
        $code = $this->codeRecu('a@b.co');
        $this->travel(11)->minutes();

        $this->essayer(['email' => 'a@b.co', 'code' => $code])
            ->assertStatus(422)->assertJsonPath('erreurs.code.0', 'Ce code a expiré : demandez-en un nouveau.');
    }

    public function test_un_nouveau_code_annule_le_precedent(): void
    {
        $this->demander('a@b.co');
        $premier = $this->codeRecu('a@b.co');
        $this->travel(61)->seconds();
        $this->demander('a@b.co', $this->defi);
        $second = $this->codeRecu('a@b.co');
        if ($premier === $second) {
            $this->markTestSkipped('Deux codes identiques tirés au hasard.');
        }

        $this->essayer(['email' => 'a@b.co', 'code' => $premier])->assertStatus(422);
        $this->essayer(['email' => 'a@b.co', 'code' => $second])->assertCreated();
    }

    public function test_un_code_par_minute_et_cinq_par_heure_et_par_adresse_au_plus(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->demander('a@b.co')->assertOk();
            $this->demander('a@b.co')->assertStatus(429)->assertHeader('Retry-After');
            $this->travel(61)->seconds();
        }
        // La sixième de l'heure : refusée, même une minute plus tard.
        $this->demander('a@b.co')->assertStatus(429);
    }

    public function test_un_e_mail_qui_ne_part_pas_est_dit_en_francais(): void
    {
        Mail::shouldReceive('to')->andThrow(new \RuntimeException('Resend injoignable'));

        $this->demander('a@b.co')
            ->assertStatus(503)->assertJsonPath('message', 'Le code n’a pas pu partir. Réessayez dans un instant.');
    }

    public function test_les_codes_de_plus_d_un_jour_sont_effaces_la_nuit(): void
    {
        $this->demander('a@b.co');
        $this->travel(25)->hours();
        $this->demander('c@d.co');

        $this->artisan('model:prune', ['--model' => [CodeEmail::class]])->assertSuccessful();
        $this->assertDatabaseMissing('codes_email', ['email' => 'a@b.co']);
        $this->assertDatabaseHas('codes_email', ['email' => 'c@d.co']);
    }

    public function test_google_cree_le_compte_puis_le_retrouve(): void
    {
        $this->app->instance(VerificateurJetonGoogle::class, new class implements VerificateurJetonGoogle
        {
            public function verifier(string $jeton): ?array
            {
                return $jeton === 'bon' ? ['sub' => '1234567890', 'email' => 'kofi@gmail.com', 'nom' => 'Kofi D.', 'photo' => null] : null;
            }
        });

        $this->postJson('/api/v1/auth/google', ['jeton' => 'bon'])->assertCreated()
            ->assertJsonPath('utilisateur.fournisseur', 'google')
            ->assertJsonPath('utilisateur.nom_affiche', 'Kofi D.');
        $this->postJson('/api/v1/auth/google', ['jeton' => 'bon'])->assertOk();
        $this->postJson('/api/v1/auth/google', ['jeton' => 'faux'])->assertStatus(422);
        $this->assertSame(1, Utilisateur::count());

        // Le même compte s'ouvre aussi avec un code envoyé à son adresse Google.
        $this->entrer('kofi@gmail.com')->assertOk()->assertJsonPath('utilisateur.fournisseur', 'google');
    }

    public function test_completer_et_modifier_le_profil(): void
    {
        $u = Utilisateur::factory()->create(['profil_complete_le' => null]);
        Utilisateur::factory()->create(['nom_utilisateur' => 'deja.pris']);

        $this->actingAs($u)->patchJson('/api/v1/moi', [
            'nom_affiche' => 'Akouavi K.',
            'nom_utilisateur' => '@Akouavi.Kossou',
            'pays' => 'Bénin',
            'ville' => 'Cotonou',
            'types_aimes' => ['Plage', 'Lac et lagune'],
            'profil_complete' => true,
        ])->assertOk()
            ->assertJsonPath('data.nom_utilisateur', 'akouavi.kossou')
            ->assertJsonPath('data.profil_complete', true)
            ->assertJsonPath('data.types_aimes', ['Plage', 'Lac et lagune']);

        $this->actingAs($u)->patchJson('/api/v1/moi', ['nom_utilisateur' => 'deja.pris'])
            ->assertStatus(422)->assertJsonPath('message', 'Le nom d’utilisateur est déjà utilisé.');
    }

    public function test_la_photo_de_profil_est_reencodee_en_webp(): void
    {
        Storage::fake('public');
        $u = Utilisateur::factory()->create();

        $this->actingAs($u)->post('/api/v1/moi/avatar', ['avatar' => UploadedFile::fake()->image('moi.jpg', 900, 1200)], ['Accept' => 'application/json'])
            ->assertOk();
        $chemin = $u->refresh()->avatar;
        $this->assertStringEndsWith('.webp', $chemin);
        Storage::disk('public')->assertExists($chemin);
        $this->assertSame([512, 512], array_slice(getimagesizefromstring(Storage::disk('public')->get($chemin)), 0, 2));

        // Retirer la photo : le fichier part, les initiales la remplacent partout.
        $this->actingAs($u)->deleteJson('/api/v1/moi/avatar')->assertOk()->assertJsonPath('data.avatar', null);
        $this->assertNull($u->refresh()->avatar);
        Storage::disk('public')->assertMissing($chemin);
    }

    public function test_sans_jeton_moi_repond_401_en_francais(): void
    {
        $this->getJson('/api/v1/moi')->assertUnauthorized()->assertExactJson(['message' => 'Connectez-vous pour continuer.']);
    }

    public function test_un_jeton_inutilise_30_jours_expire(): void
    {
        $u = Utilisateur::factory()->create();
        $jeton = $u->createToken('téléphone')->plainTextToken;
        $this->travel(31)->days();

        $this->getJson('/api/v1/moi', ['Authorization' => "Bearer {$jeton}"])->assertUnauthorized();
    }

    public function test_se_deconnecter_retire_seulement_ce_jeton(): void
    {
        $u = Utilisateur::factory()->create();
        $ici = $u->createToken('ici')->plainTextToken;
        $u->createToken('ailleurs');

        $this->postJson('/api/v1/auth/deconnexion', [], ['Authorization' => "Bearer {$ici}"])->assertOk();
        $this->assertSame(1, $u->tokens()->count());
    }

    public function test_supprimer_son_compte_retire_tous_les_jetons(): void
    {
        $u = Utilisateur::factory()->create();
        $ici = $u->createToken('ici')->plainTextToken;
        $u->createToken('ailleurs');

        $this->deleteJson('/api/v1/moi', [], ['Authorization' => "Bearer {$ici}"])
            ->assertOk()->assertJsonStructure(['message', 'supprime_le']);
        $this->assertSame(0, $u->tokens()->count());
        $this->assertNotNull($u->refresh()->suppression_demandee_le);
    }

    public function test_se_reconnecter_avant_30_jours_annule_la_suppression(): void
    {
        $u = Utilisateur::factory()->create(['email' => 'akouavi@gmail.com']);
        $this->deleteJson('/api/v1/moi', [], ['Authorization' => 'Bearer '.$u->createToken('ici')->plainTextToken])->assertOk();
        $this->travel(10)->days();

        $this->entrer('akouavi@gmail.com')->assertOk();
        $this->assertNull($u->refresh()->suppression_demandee_le);
    }

    public function test_les_comptes_sont_effaces_apres_30_jours_seulement(): void
    {
        $parti = Utilisateur::factory()->create(['suppression_demandee_le' => now()->subDays(31)]);
        $recent = Utilisateur::factory()->create(['suppression_demandee_le' => now()->subDays(5)]);
        $reste = Utilisateur::factory()->create();

        $this->artisan('usw:purger-comptes')->assertSuccessful();

        $this->assertModelMissing($parti);
        $this->assertModelExists($recent);
        $this->assertModelExists($reste);
    }

    public function test_changer_d_adresse_avec_un_code_sur_la_nouvelle_et_l_ancienne_prevenue(): void
    {
        $u = Utilisateur::factory()->create(['email' => 'ancienne@exemple.bj', 'fournisseur' => 'email']);
        Utilisateur::factory()->create(['email' => 'prise@exemple.bj']);

        $this->actingAs($u)->postJson('/api/v1/moi/email', ['email' => 'prise@exemple.bj'])->assertOk();
        Mail::assertNotSent(CodeParEmail::class, fn (CodeParEmail $m) => $m->hasTo('prise@exemple.bj'));
        $this->actingAs($u)->postJson('/api/v1/moi/email/confirmer', ['code' => '123456'])->assertStatus(422);
        $this->actingAs($u)->postJson('/api/v1/moi/email', ['email' => 'ancienne@exemple.bj'])->assertStatus(422);
        $this->actingAs($u)->postJson('/api/v1/moi/email', ['email' => ' Nouvelle@Exemple.bj '])->assertOk();
        $code = $this->codeRecu('nouvelle@exemple.bj');

        // Ce code confirme l'adresse : il n'ouvre pas de compte.
        $this->essayer(['email' => 'nouvelle@exemple.bj', 'code' => $code])->assertStatus(422);
        $this->actingAs($u)->postJson('/api/v1/moi/email/confirmer', ['code' => '000000'])->assertStatus(422);
        $this->actingAs($u)->postJson('/api/v1/moi/email/confirmer', ['code' => $code])->assertOk()->assertJsonPath('data.email', 'nouvelle@exemple.bj');
        $this->assertSame('nouvelle@exemple.bj', $u->fresh()->email);
        Mail::assertSent(AdresseChangee::class, fn (AdresseChangee $m) => $m->hasTo('ancienne@exemple.bj'));
    }

    public function test_mes_donnees_s_exportent_sans_secret(): void
    {
        $u = Utilisateur::factory()->create(['email' => 'moi@exemple.bj']);
        Contenu::factory()->create(['utilisateur_id' => $u->id]);

        $r = $this->actingAs($u)->getJson('/api/v1/moi/donnees')->assertOk()
            ->assertJsonPath('compte.email', 'moi@exemple.bj')
            ->assertJsonCount(1, 'publications');
        $this->assertStringNotContainsString('code_hache', $r->getContent());
        $this->assertStringNotContainsString('google_sub', $r->getContent());
    }

    public function test_un_compte_lie_a_google_garde_l_adresse_de_google(): void
    {
        $u = Utilisateur::factory()->create(['email' => 'moi@gmail.com', 'fournisseur' => 'google', 'google_sub' => 'g-123']);

        $this->actingAs($u)->getJson('/api/v1/moi')->assertJsonPath('data.google', true);
        $this->actingAs($u)->postJson('/api/v1/moi/email', ['email' => 'autre@exemple.bj'])->assertStatus(409);
    }
}
