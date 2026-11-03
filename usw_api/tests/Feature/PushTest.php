<?php

namespace Tests\Feature;

use App\Jobs\PrevenirAbonnes;
use App\Models\Abonnement;
use App\Models\AppareilPush;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** Les notifications sur le téléphone (Firebase) : l'enregistrement, les réglages, l'oubli. */
class PushTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Un compte de service de test : une vraie clé RSA (de test, sans usage ailleurs), pour
        // signer le jeton OAuth.
        config(['discover.firebase' => base64_encode(json_encode([
            'project_id' => 'discover-test',
            'client_email' => 'push@discover-test.iam.gserviceaccount.com',
            'private_key' => file_get_contents(base_path('tests/Fixtures/firebase-test.pem')),
            'token_uri' => 'https://oauth2.googleapis.com/token',
        ]))]);
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'acces-test', 'expires_in' => 3600]),
            'fcm.googleapis.com/*' => fn () => $this->reponseFirebase ?? Http::response(['name' => 'projects/discover-test/messages/1']),
        ]);
    }

    /** Ce que Firebase répond (par défaut : notification prise). */
    private mixed $reponseFirebase = null;

    private function envois(): array
    {
        return Http::recorded(fn (Request $r) => str_contains($r->url(), 'fcm.googleapis.com'))->values()->all();
    }

    public function test_un_telephone_enregistre_recoit_les_notifications_selon_ses_reglages(): void
    {
        $ama = Utilisateur::factory()->create(['nom_affiche' => 'Ama']);
        $kofi = Utilisateur::factory()->create(['nom_affiche' => 'Kofi D.']);
        $jeton = $ama->createToken('Samsung')->plainTextToken;
        $this->withToken($jeton)->putJson('/api/v1/moi/push', ['jeton' => 'fcm-ama', 'preferences' => ['jaime' => true, 'abonnes' => false]])->assertOk();
        $this->assertSame(1, AppareilPush::count());

        Activite::a($ama, new Activite('reaction', 'a réagi à votre publication.', $kofi));
        Activite::a($ama, new Activite('abonne', 's’est abonné à vous.', $kofi));
        $envois = $this->envois();
        $this->assertCount(1, $envois);
        [$requete] = $envois[0];
        $this->assertSame('Bearer acces-test', $requete->header('Authorization')[0]);
        $this->assertSame('fcm-ama', $requete['message']['token']);
        $this->assertSame('Kofi D.', $requete['message']['notification']['title']);
        $this->assertSame('reaction', $requete['message']['data']['genre']);

        // Le message de l'équipe prévient toujours, même en pause.
        AppareilPush::query()->update(['pause_jusqu_a' => now()->addHours(8)]);
        Activite::a($ama, new Activite('reaction', 'a réagi à votre publication.', $kofi));
        $ama->notify(new Activite('equipe', 'Bienvenue sur Discover.', ton: 'info'));
        $this->assertCount(2, $this->envois());
        $this->assertSame('L’équipe de Discover', $this->envois()[1][0]['message']['notification']['title']);
    }

    public function test_un_jeton_que_firebase_ne_connait_plus_est_oublie(): void
    {
        $this->reponseFirebase = Http::response(['error' => ['status' => 'NOT_FOUND', 'details' => [['errorCode' => 'UNREGISTERED']]]], 404);
        $ama = Utilisateur::factory()->create();
        $this->actingAs($ama)->putJson('/api/v1/moi/push', ['jeton' => 'fcm-perime'])->assertOk();
        $ama->notify(new Activite('equipe', 'Bonjour.', ton: 'info'));
        $this->assertSame(0, AppareilPush::count());
    }

    public function test_deconnecte_coupe_ou_suspendu_le_telephone_ne_recoit_plus_rien(): void
    {
        $ama = Utilisateur::factory()->create();
        $jeton = $ama->createToken('Samsung')->plainTextToken;
        $this->withToken($jeton)->putJson('/api/v1/moi/push', ['jeton' => 'fcm-1'])->assertOk();
        $this->withToken($jeton)->postJson('/api/v1/auth/deconnexion')->assertOk();
        $this->assertSame(0, AppareilPush::count());

        $this->actingAs($ama)->putJson('/api/v1/moi/push', ['jeton' => 'fcm-2'])->assertOk();
        $this->actingAs($ama)->deleteJson('/api/v1/moi/push', ['jeton' => 'fcm-2'])->assertOk();
        $this->assertSame(0, AppareilPush::count());

        // Un autre membre ne peut pas reprendre ni effacer ce téléphone d'un autre compte par erreur :
        // le jeton suit le compte qui l'a enregistré en dernier.
        $kofi = Utilisateur::factory()->create();
        $this->actingAs($ama)->putJson('/api/v1/moi/push', ['jeton' => 'fcm-3'])->assertOk();
        $this->actingAs($kofi)->deleteJson('/api/v1/moi/push', ['jeton' => 'fcm-3'])->assertOk();
        $this->assertSame(1, AppareilPush::count());

        config(['discover.admins' => ['equipe@discover.bj']]);
        $equipe = Utilisateur::factory()->create(['email' => 'equipe@discover.bj']);
        $this->actingAs($equipe)->postJson("/api/v1/admin/membres/{$ama->nom_utilisateur}/suspension", ['motif' => 'Spam ou arnaque'])->assertOk();
        $this->assertSame(0, AppareilPush::count());
    }

    public function test_sans_firebase_rien_ne_part(): void
    {
        config(['discover.firebase' => null]);
        $ama = Utilisateur::factory()->create();
        $this->actingAs($ama)->putJson('/api/v1/moi/push', ['jeton' => 'fcm-ama'])->assertOk();
        $ama->notify(new Activite('equipe', 'Bonjour.', ton: 'info'));
        $this->assertCount(0, $this->envois());
        $this->assertSame(1, $ama->notifications()->count());
    }

    public function test_les_abonnes_qui_l_ont_demande_sont_prevenus_d_une_nouvelle_publication(): void
    {
        $createur = Utilisateur::factory()->create();
        $veut = Utilisateur::factory()->create();
        $neVeutPas = Utilisateur::factory()->create();
        foreach ([$veut, $neVeutPas] as $a) {
            Abonnement::create(['abonne_id' => $a->id, 'createur_id' => $createur->id]);
        }
        AppareilPush::create(['utilisateur_id' => $veut->id, 'jeton' => 'jeton-veut', 'preferences' => ['suivis' => true]]);
        AppareilPush::create(['utilisateur_id' => $neVeutPas->id, 'jeton' => 'jeton-non', 'preferences' => ['suivis' => false]]);
        $c = Contenu::factory()->create(['utilisateur_id' => $createur->id]);

        (new PrevenirAbonnes($c))->handle();

        $this->assertSame(1, $veut->notifications()->where('data->genre', 'suivi')->count());
        $this->assertSame(0, $neVeutPas->notifications()->count());
    }
}
