<?php

namespace App\Console\Commands;

use App\Enums\TypeContenu;
use App\Enums\UsageVariante;
use App\Models\Contenu;
use App\Services\Contenus\Variantes;
use App\Support\Medias;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Throwable;

/**
 * Toutes les minutes : l'aperçu léger (640 px, sans son) des reels publiés avant lui, tiré de leur
 * 720p, les plus récents d'abord. Un raté ne se redemande que le lendemain.
 */
#[Signature('usw:apercus-video {--limite=2 : reels au plus par passage}')]
#[Description('Fabrique l\'aperçu léger des reels qui n\'en ont pas (lu dans les grilles)')]
class ApercusVideo extends Command
{
    public function handle(Variantes $variantes): int
    {
        if (! config('services.ffmpeg.chemin')) {
            return self::SUCCESS;
        }
        $reels = Contenu::where('type', TypeContenu::Reel)
            ->whereHas('variantes', fn ($q) => $q->where('usage', UsageVariante::Video))
            ->whereDoesntHave('variantes', fn ($q) => $q->where('usage', UsageVariante::VideoApercu))
            ->with('variantes')->orderByDesc('id')->limit(20)->get()
            ->reject(fn (Contenu $c) => Cache::has("apercu-video-rate-{$c->id}"))
            ->take((int) $this->option('limite'));
        foreach ($reels as $c) {
            $video = $c->variantes->firstWhere('usage', UsageVariante::Video);
            $source = Medias::travail()->path("contenus/{$c->ulid}/video-apercu-source.mp4");
            try {
                if (! is_dir(dirname($source))) {
                    mkdir(dirname($source), 0700, true);
                }
                $flux = Medias::public()->readStream($video->chemin);
                file_put_contents($source, $flux);
                if (is_resource($flux)) {
                    fclose($flux);
                }
                $fait = $variantes->apercuVideo($c, $source);
            } catch (Throwable $e) {
                report($e);
                $fait = false;
            } finally {
                @unlink($source);
            }
            if (! $fait) {
                Cache::put("apercu-video-rate-{$c->id}", true, now()->addDay());
            }
        }

        return self::SUCCESS;
    }
}
