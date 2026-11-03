<?php

namespace Tests\Feature;

use App\Models\Son;
use App\Models\Utilisateur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Process\PendingProcess;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** Les sons importés par les membres : le son d'une vidéo, un fichier du téléphone, comme le « son original » de TikTok. */
class SonsDesMembresTest extends TestCase
{
    use RefreshDatabase;

    private Utilisateur $ola;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake(config('discover.medias'));
        config(['services.ffmpeg.chemin' => 'ffmpeg']);
        $this->ola = Utilisateur::factory()->create(['nom_utilisateur' => 'ola', 'nom_affiche' => 'Ola']);
    }

    /** ffmpeg simulé : la conversion écrit le son, la lecture de l'onde rend un son régulier. */
    private function ffmpeg(int $dureeMs = 12_500, bool $lisible = true): void
    {
        Process::fake(function (PendingProcess $p) use ($dureeMs, $lisible) {
            $commande = $p->command;
            if (in_array('-c:a', $commande, true)) {
                if (! $lisible) {
                    return Process::result(errorOutput: 'Invalid data found when processing input', exitCode: 1);
                }
                file_put_contents(end($commande), 'son');
                $s = intdiv($dureeMs, 1000);

                return Process::result(errorOutput: sprintf('Duration: 00:%02d:%02d.%02d, start', intdiv($s, 60), $s % 60, intdiv($dureeMs % 1000, 10)));
            }

            return Process::result(output: str_repeat(pack('s', 1200), 4000));
        });
    }

    public function test_importer_le_son_d_une_video_et_le_choisir_pour_son_reel(): void
    {
        $this->ffmpeg();
        $r = $this->actingAs($this->ola)->post('/api/v1/sons', ['fichier' => UploadedFile::fake()->create('soiree.m4a', 300, 'audio/mp4'), 'titre' => 'Soirée à Cotonou'], ['Accept' => 'application/json']);

        $r->assertCreated()->assertJsonPath('data.titre', 'Soirée à Cotonou')->assertJsonPath('data.artiste', 'Ola')
            ->assertJsonPath('data.importe', true)->assertJsonPath('data.duree_ms', 12_500);
        $son = Son::where('ulid', $r->json('data.id'))->first();
        Storage::disk(config('discover.medias'))->assertExists($son->chemin);
        // Mes sons : il est là ; le catalogue des autres : pas avant qu'un reel l'ait en ligne.
        $this->actingAs($this->ola)->getJson('/api/v1/sons?categorie=miens')->assertJsonCount(1, 'data');
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/sons')->assertJsonCount(0, 'data');
        Son::whereKey($son->id)->update(['nombre_reels' => 1]);
        $this->getJson('/api/v1/sons')->assertJsonCount(1, 'data');
    }

    public function test_un_fichier_sans_son_ou_trop_long_est_refuse(): void
    {
        $this->ffmpeg(lisible: false);
        $this->actingAs($this->ola)->post('/api/v1/sons', ['fichier' => UploadedFile::fake()->create('photo.jpg', 30)], ['Accept' => 'application/json'])->assertUnprocessable();
        $this->assertSame(0, Son::count());
    }

    public function test_trop_long(): void
    {
        $this->ffmpeg(dureeMs: 700_000);
        $this->actingAs($this->ola)->post('/api/v1/sons', ['fichier' => UploadedFile::fake()->create('concert.mp3', 300, 'audio/mpeg')], ['Accept' => 'application/json'])->assertUnprocessable();
        $this->assertSame(0, Son::count());
    }

    public function test_signale_par_trois_membres_il_est_retire(): void
    {
        $this->ffmpeg();
        $id = $this->actingAs($this->ola)->post('/api/v1/sons', ['fichier' => UploadedFile::fake()->create('voix.m4a', 100, 'audio/mp4')], ['Accept' => 'application/json'])->json('data.id');
        $son = Son::where('ulid', $id)->first();
        $this->assertSame('Son original', $son->titre);

        foreach (Utilisateur::factory()->count(3)->create() as $i => $u) {
            $this->app['auth']->forgetGuards();
            $this->actingAs($u)->postJson("/api/v1/sons/{$id}/signaler")->assertNoContent();
            // Le même membre deux fois ne compte qu'une.
            $this->actingAs($u)->postJson("/api/v1/sons/{$id}/signaler")->assertNoContent();
            $this->assertSame($i < 2, $son->refresh()->actif);
        }
        $this->assertSame(3, $son->signalements);
    }

    public function test_un_son_du_catalogue_ne_se_signale_pas(): void
    {
        $catalogue = Son::create([
            'cle' => 'test:allada', 'titre' => 'Allada', 'artiste' => 'Kevin MacLeod', 'categorie' => 'afro', 'duree_ms' => 180_000,
            'chemin' => 'sons/allada.m4a', 'forme' => [], 'debut_conseille_ms' => 0, 'licence' => 'CC BY 4.0', 'attribution' => 'Kevin MacLeod',
        ]);
        $this->actingAs($this->ola)->postJson("/api/v1/sons/{$catalogue->ulid}/signaler")->assertUnprocessable();
        $this->postJson('/api/v1/sons', [])->assertUnprocessable();
    }
}
