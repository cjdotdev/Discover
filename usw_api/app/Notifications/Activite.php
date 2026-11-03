<?php

namespace App\Notifications;

use App\Enums\Badge;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\Utilisateur;
use App\Notifications\Canaux\CanalPush;
use App\Support\Langues;
use App\Support\Medias;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

/**
 * Ce qui arrive à un membre (E17) : une réaction, un commentaire, une réponse, une mention, un
 * abonné, la décision sur une publication. Gardé en base (le centre des notifications), et
 * envoyé aux téléphones du membre (Firebase), selon ses réglages.
 */
class Activite extends Notification
{
    use Queueable;

    /**
     * @param  string  $genre  reaction, commentaire, reponse, mention, abonne, suivi, publiee, refusee, equipe
     * @param  string|null  $ton  le message de l'équipe : felicitations, avertissement, info
     * @param  string  $texte  en français ; traduit dans la langue du destinataire à l'envoi
     *                         (:nom est remplacé par $valeurs['nom'])
     */
    public function __construct(
        public string $genre,
        public string $texte,
        public ?Utilisateur $acteur = null,
        public ?Contenu $contenu = null,
        public ?Commentaire $commentaire = null,
        public ?string $ton = null,
        public array $valeurs = [],
    ) {}

    public function via(object $notifiable): array
    {
        return ['database', CanalPush::class];
    }

    /** La ligne des réglages de notifications qui décide ; absente : prévient toujours. */
    private const PREFERENCES = [
        'reaction' => 'jaime',
        'commentaire' => 'commentaires',
        'reponse' => 'commentaires',
        'mention' => 'mentions',
        'abonne' => 'abonnes',
        'publiee' => 'verifiee',
        'suivi' => 'suivis',
    ];

    /** La notification sur le téléphone : qui, quoi, et où aller quand on la touche. */
    public function toPush(object $notifiable): array
    {
        $photo = $this->contenu?->variantes()->whereIn('usage', ['480', 'affiche'])->value('chemin');

        return [
            'preference' => self::PREFERENCES[$this->genre] ?? null,
            'titre' => match (true) {
                $this->genre === 'equipe' => __('L’équipe de Discover', [], $notifiable->langue ?: Langues::SOURCE),
                $this->acteur !== null => $this->acteur->nom_affiche ?: '@'.$this->acteur->nom_utilisateur,
                default => 'Discover',
            },
            'corps' => $this->texte,
            'image' => $photo ? Medias::public()->url($photo) : null,
            'donnees' => array_filter([
                'genre' => $this->genre,
                'contenu' => $this->contenu?->ulid,
                'type' => $this->contenu?->type->value,
                'acteur' => $this->acteur?->nom_utilisateur,
                'commentaire' => $this->commentaire?->ulid,
            ]),
        ];
    }

    public function databaseType(object $notifiable): string
    {
        return $this->genre;
    }

    public function toArray(object $notifiable): array
    {
        $photo = $this->contenu?->variantes()->whereIn('usage', ['480', 'affiche'])->value('chemin');

        return [
            'genre' => $this->genre,
            'texte' => $this->texte,
            'acteur' => $this->acteur === null ? null : [
                // Son identifiant : le centre des notifications relit sa photo et son nom du jour.
                'id' => $this->acteur->ulid,
                'nom_utilisateur' => $this->acteur->nom_utilisateur,
                'nom_affiche' => $this->acteur->nom_affiche,
                'avatar' => $this->acteur->avatar ? Medias::public()->url($this->acteur->avatar) : null,
            ],
            'contenu' => $this->contenu === null ? null : [
                'id' => $this->contenu->ulid,
                'type' => $this->contenu->type->value,
                'badge' => $this->contenu->badge?->value,
                'lieu' => $this->contenu->lieu()->value('slug'),
                'photo' => $photo ? Medias::public()->url($photo) : null,
            ],
            'commentaire' => $this->commentaire?->ulid,
            'ton' => $this->ton,
        ];
    }

    /** Envoyer, sauf à soi-même (on ne se notifie pas de sa propre réaction). */
    /** « Votre publication est en ligne » : vérifiée seulement si la capture l'est. */
    public static function textePubliee(?Badge $badge): string
    {
        return $badge === Badge::Verifiee ? 'Votre publication est en ligne. Capture vérifiée.' : 'Votre publication est en ligne. Informations déclarées.';
    }

    public static function a(?Utilisateur $destinataire, self $n): void
    {
        if ($destinataire === null || ($n->acteur !== null && $n->acteur->id === $destinataire->id)) {
            return;
        }
        // Quelqu'un que l'on a bloqué ne nous notifie plus.
        if ($n->acteur !== null && $destinataire->aBloque($n->acteur)) {
            return;
        }
        // Dans la langue de son application (le français s'il ne l'a jamais dit).
        $langue = $destinataire->langue ?: Langues::SOURCE;
        $valeurs = array_map(fn ($v) => is_string($v) ? __($v, [], $langue) : $v, $n->valeurs);
        $n->texte = __($n->texte, $valeurs, $langue);
        $destinataire->notify($n);
    }
}
