<?php

namespace App\Services\Contenus;

use App\Enums\Badge;
use App\Models\Abonnement;
use App\Models\Contenu;
use App\Models\Etiquette;
use App\Models\Lieu;
use App\Models\Utilisateur;
use App\Models\Vue;
use App\Support\Themes;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * La recommandation de Discover.
 *
 *  - Le score d'une publication, le même pour tous : ce qu'elle suscite (réactions,
 *    commentaires, enregistrements, partages, vues, vues jusqu'au bout), un peu plus si sa
 *    capture est vérifiée, adouci par son âge pour qu'une publication toute neuve ait sa chance
 *    même sans réaction. Recalculé toutes les 10 minutes (usw:scores) et dès la publication.
 *  - Le score d'un lieu : la somme de ses 5 meilleures publications (l'ordre de l'accueil).
 *  - Les reels « Pour toi », propres à chacun : les meilleurs candidats, remontés si l'on suit
 *    leur créateur ou si leur lieu est d'un type que l'on aime, descendus si on les a déjà vus
 *    ou si l'on n'est pas intéressé par leur créateur (« Pas intéressé » les retire) ;
 *    puis jamais deux du même créateur à la suite. L'ordre est gardé 15 minutes, le temps de
 *    défiler les pages ; tirer pour actualiser le refait.
 */
class Recommandation
{
    /** Les reels considérés pour « Pour toi » (les mieux notés). */
    public const CANDIDATS = 300;

    /** La demi-vie de la fraîcheur, en heures : à 36 h, une publication vaut à peu près moitié moins. */
    private const FRAICHEUR_H = 36.0;

    private const POIDS = [
        'nombre_reactions' => 3.0,
        'nombre_commentaires' => 4.0,
        'nombre_enregistrements' => 5.0,
        'nombre_partages' => 6.0,
        'nombre_vues' => 0.3,
        'nombre_vues_completes' => 0.7,
    ];

    /** Le score d'une publication, pour tous. */
    public static function score(Contenu $c, ?CarbonInterface $maintenant = null): float
    {
        $maintenant ??= now();
        $engagement = 1.0;
        foreach (self::POIDS as $champ => $poids) {
            $engagement += $poids * (int) $c->getAttribute($champ);
        }
        $qualite = 1 + log($engagement) + ($c->badge === Badge::Verifiee ? 0.5 : 0);
        $heures = $c->publie_le === null ? 0 : max(0, $c->publie_le->diffInMinutes($maintenant, false) / 60);

        return round($qualite / (1 + $heures / self::FRAICHEUR_H) ** 1.3, 6);
    }

    /** Le score d'une publication, enregistré (sans toucher à sa date de modification). */
    public static function noter(Contenu $c): void
    {
        Contenu::whereKey($c->id)->toBase()->update(['score' => self::score($c)]);
        self::noterLieu($c->lieu_id);
    }

    /** Le score d'un lieu : la somme de ses 5 meilleures publications. */
    public static function noterLieu(?int $id): void
    {
        if ($id === null) {
            return;
        }
        $score = (float) Contenu::publies()->where('lieu_id', $id)->orderByDesc('score')->limit(5)->pluck('score')->sum();
        Lieu::whereKey($id)->toBase()->update(['score' => round($score, 6)]);
    }

    /** Tous les scores (usw:scores) : l'âge les fait baisser, l'engagement les fait monter. */
    public static function recalculer(): int
    {
        $maintenant = now();
        $n = 0;
        Contenu::publies()->select(['id', 'lieu_id', 'badge', 'publie_le', 'score', ...array_keys(self::POIDS)])
            ->chunkById(500, function ($lot) use ($maintenant, &$n) {
                foreach ($lot as $c) {
                    $s = self::score($c, $maintenant);
                    if (abs($s - (float) $c->score) > 1e-6) {
                        Contenu::whereKey($c->id)->toBase()->update(['score' => $s]);
                        $n++;
                    }
                }
            });
        Lieu::query()->where('nombre_contenus', '>', 0)->select('id')->chunkById(500, function ($lieux) {
            foreach ($lieux as $l) {
                self::noterLieu($l->id);
            }
        });
        // Les publications retirées ou masquées ne comptent plus pour leur lieu.
        Lieu::query()->where('nombre_contenus', 0)->where('score', '>', 0)->toBase()->update(['score' => 0]);

        return $n;
    }

    /**
     * Les identifiants des reels « Pour toi », dans l'ordre, pour ce spectateur.
     *
     * @return list<int>
     */
    public function reels(?Utilisateur $moi, string $spectateur, bool $refaire): array
    {
        $cle = 'reco:reels:'.$spectateur;
        if (! $refaire && is_array($ordre = Cache::get($cle))) {
            return $ordre;
        }
        $ordre = $this->classer($moi, $spectateur);
        Cache::put($cle, $ordre, now()->addMinutes(15));

        return $ordre;
    }

    /** @return list<int> */
    private function classer(?Utilisateur $moi, string $spectateur): array
    {
        $candidats = Contenu::publies()->reels()->sansBloques($moi)
            ->orderByDesc('score')->orderByDesc('id')->limit(self::CANDIDATS)
            ->get(['contenus.id', 'contenus.utilisateur_id', 'contenus.lieu_id', 'contenus.score']);
        if ($candidats->isEmpty()) {
            return [];
        }
        $ids = $candidats->pluck('id');
        $suivis = $moi ? Abonnement::where('abonne_id', $moi->id)->pluck('createur_id')->flip() : collect();
        $types = $moi?->types_aimes ?? [];
        $lieuxAimes = $types
            ? Lieu::whereIn('id', $candidats->pluck('lieu_id')->filter()->unique())->whereIn('type', $types)->pluck('id')->flip()
            : collect();
        // Les goûts choisis à l'inscription (nature, mer, nourriture…) : ce qu'on voit sur la vidéo.
        $themes = array_values(array_intersect($types, array_keys(Themes::THEMES)));
        $aimesParTheme = $themes
            ? Etiquette::whereIn('contenu_id', $ids)->whereIn('nom', Themes::etiquettesDes($themes))->where('confiance', '>=', Themes::CONFIANCE)->distinct()->pluck('contenu_id')->flip()
            : collect();
        $vus = Vue::where('spectateur', $spectateur)->where('jour', '>=', today()->subDays(30))
            ->whereIn('contenu_id', $ids)->pluck('contenu_id')->flip();
        // « Pas intéressé » : la publication sort, son créateur passe moins souvent (90 jours).
        $desinterets = DB::table('desinterets')->where('spectateur', $spectateur)->where('created_at', '>=', now()->subDays(90))->get(['contenu_id', 'auteur_id']);
        $ecartes = $desinterets->pluck('contenu_id')->flip();
        $moinsDe = $desinterets->pluck('auteur_id')->flip();
        $candidats = $candidats->reject(fn (Contenu $c) => $ecartes->has($c->id))->values();

        $notes = $candidats->map(function (Contenu $c) use ($moi, $suivis, $lieuxAimes, $aimesParTheme, $vus, $moinsDe) {
            $s = (float) $c->score;
            if ($moinsDe->has($c->utilisateur_id)) {
                $s *= 0.4;
            }
            if ($suivis->has($c->utilisateur_id)) {
                $s *= 1.6;
            }
            if (($c->lieu_id !== null && $lieuxAimes->has($c->lieu_id)) || $aimesParTheme->has($c->id)) {
                $s *= 1.3;
            }
            if ($vus->has($c->id)) {
                $s *= 0.25;
            }
            if ($moi !== null && $c->utilisateur_id === $moi->id) {
                $s *= 0.5;
            }

            return ['id' => (int) $c->id, 'auteur' => (int) $c->utilisateur_id, 'note' => $s];
        })->sortByDesc('note')->values()->all();

        // La diversité : un créateur ne revient pas avant 2 reels d'autres créateurs, tant qu'il y en a.
        $ordre = [];
        $derniers = [];
        while ($notes) {
            $i = 0;
            foreach ($notes as $k => $n) {
                if (! in_array($n['auteur'], $derniers, true)) {
                    $i = $k;
                    break;
                }
            }
            $choisi = $notes[$i];
            array_splice($notes, $i, 1);
            $ordre[] = $choisi['id'];
            $derniers = array_slice([...$derniers, $choisi['auteur']], -2);
        }

        return $ordre;
    }
}
