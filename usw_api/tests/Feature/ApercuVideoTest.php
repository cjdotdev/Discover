<?php

namespace Tests\Feature;

use App\Enums\UsageVariante;
use App\Models\Contenu;
use App\Support\Medias;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Process\PendingProcess;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** L'aperçu léger des reels (640 px, sans son), lu dans les grilles comme sur Pinterest. */
class ApercuVideoTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake(config('discover.medias'));
        config(['services.ffmpeg.chemin' => 'ffmpeg']);
    }

    private function reel(): Contenu
    {
        $c = Contenu::factory()->reel()->complet()->create(['publie_le' => now()]);
        Medias::public()->put("contenus/{$c->ulid}/video.mp4", 'video 720p');
        $c->variantes()->create(['usage' => UsageVariante::Video, 'chemin' => "contenus/{$c->ulid}/video.mp4"]);

        return $c;
    }

    public function test_les_reels_d_avant_recoivent_leur_apercu_sans_le_son(): void
    {
        $commandes = [];
        Process::fake(function (PendingProcess $p) use (&$commandes) {
            $commandes[] = $p->command;
            file_put_contents(end($p->command), 'apercu');

            return Process::result();
        });
        $c = $this->reel();

        $this->artisan('usw:apercus-video')->assertSuccessful();

        $apercu = $c->variantes()->where('usage', UsageVariante::VideoApercu)->first();
        $this->assertNotNull($apercu);
        Medias::public()->assertExists("contenus/{$c->ulid}/video-640.mp4");
        $this->assertContains('-an', $commandes[0]);
        // L'API le donne aux grilles ; le téléchargement garde la meilleure version.
        $this->getJson("/api/v1/contenus/{$c->ulid}")->assertOk()->assertJsonPath('data.images.video-640.url', $apercu->url());
        Process::assertRanTimes(fn () => true, 1);

        // Fait : il ne se refait pas.
        $this->artisan('usw:apercus-video')->assertSuccessful();
        Process::assertRanTimes(fn () => true, 1);
    }

    public function test_un_apercu_rate_ne_se_redemande_que_le_lendemain(): void
    {
        Process::fake(fn () => Process::result(exitCode: 1));
        $c = $this->reel();

        $this->artisan('usw:apercus-video')->assertSuccessful();
        $this->artisan('usw:apercus-video')->assertSuccessful();

        $this->assertFalse($c->variantes()->where('usage', UsageVariante::VideoApercu)->exists());
        Process::assertRanTimes(fn () => true, 1);
    }
}
