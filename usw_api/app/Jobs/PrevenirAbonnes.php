<?php

namespace App\Jobs;

use App\Enums\TypeContenu;
use App\Models\AppareilPush;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Notifications\Activite;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Une première publication en ligne : ses abonnés qui l'ont demandé (Réglages, Notifications,
 * « Nouvelles publications ») sont prévenus. Par paquets de 200, pour ne rien bloquer.
 */
class PrevenirAbonnes implements ShouldQueue
{
    use Queueable;

    public function __construct(public Contenu $contenu) {}

    public function handle(): void
    {
        $c = $this->contenu->fresh('auteur');
        // Une publication de lifestyle ne prévient personne : elle ne passe pas à l'accueil.
        if ($c === null || ! $c->estVisible() || $c->auteur === null || $c->estDuLifestyle()) {
            return;
        }
        $texte = $c->type === TypeContenu::Reel ? 'a publié un nouveau reel.' : 'a publié une nouvelle photo.';
        Utilisateur::query()
            ->whereIn('id', fn ($q) => $q->select('abonne_id')->from('abonnements')->where('createur_id', $c->utilisateur_id))
            ->whereNull('suspendu_le')
            ->with('appareilsPush')
            ->chunkById(200, function ($abonnes) use ($c, $texte) {
                foreach ($abonnes as $abonne) {
                    // Seulement ceux qui l'ont demandé sur au moins un téléphone (désactivé par défaut).
                    if ($abonne->appareilsPush->contains(fn (AppareilPush $a) => ($a->preferences['suivis'] ?? false) === true)) {
                        Activite::a($abonne, new Activite('suivi', $texte, $c->auteur, $c));
                    }
                }
            });
    }
}
