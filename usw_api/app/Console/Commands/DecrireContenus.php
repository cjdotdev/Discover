<?php

namespace App\Console\Commands;

use App\Enums\UsageVariante;
use App\Models\Contenu;
use App\Models\Lieu;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Toutes les minutes : l'IA (Cloudflare Workers AI, ia/ia.js) décrit les publications en ligne qui
 * ne le sont pas encore, les plus récentes d'abord ; les anciennes suivent, quelques-unes à chaque
 * passage. Une IA indisponible : la publication se redemande au passage suivant.
 */
#[Signature('usw:decrire {--limite=10 : publications au plus par passage}')]
#[Description('Fait décrire par l\'IA ce qu\'on voit sur les publications (recherche par le contenu)')]
class DecrireContenus extends Command
{
    public function handle(): int
    {
        $url = rtrim((string) config('services.ia.url'), '/');
        if ($url === '') {
            return self::SUCCESS;
        }
        $contenus = Contenu::publies()->whereNull('decrit_le')->with('variantes')
            ->orderByDesc('publie_le')->limit((int) $this->option('limite'))->get();
        $faites = 0;
        foreach ($contenus as $c) {
            // La photo à l'écran (1080 px), ou l'affiche d'une vidéo.
            $image = $c->variantes->firstWhere('usage', UsageVariante::Affiche)
                ?? $c->variantes->firstWhere('usage', UsageVariante::Ecran)
                ?? $c->variantes->firstWhere('usage', UsageVariante::Petite);
            if ($image === null) {
                continue;
            }
            try {
                $r = Http::timeout(60)->post($url.'/decrire', ['image' => $image->url()]);
            } catch (Throwable $e) {
                report($e);

                continue;
            }
            if ($r->successful() && is_string($r->json('description'))) {
                $mots = array_values(array_filter((array) $r->json('mots'), 'is_string'));
                $description = mb_substr(trim($r->json('description')), 0, 600);
                $c->forceFill([
                    'description_ia' => $description,
                    // Entre espaces : la recherche y cherche des mots entiers (« mer », pas « commerce »).
                    'recherche_ia' => ' '.Lieu::normaliser($description.' '.implode(' ', $mots)).' ',
                    'decrit_le' => now(),
                ])->saveQuietly();
                $faites++;
            } elseif (in_array($r->status(), [404, 413, 422], true)) {
                // Une image refusée ou absente ne se redemande pas sans fin.
                $c->forceFill(['decrit_le' => now()])->saveQuietly();
            }
        }
        $this->info("{$faites} publication(s) décrite(s).");

        return self::SUCCESS;
    }
}
