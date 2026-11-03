<?php

namespace App\Notifications\Canaux;

use App\Jobs\EnvoyerPush;
use App\Models\Utilisateur;
use App\Services\Push\Firebase;
use Illuminate\Notifications\Notification;

/**
 * Le canal « push » : la notification part vers chaque téléphone du membre qui la veut
 * (ses réglages, sa pause). Une notification le dit avec toPush() ; null, elle ne part pas.
 */
class CanalPush
{
    public function __construct(private Firebase $firebase) {}

    public function send(object $notifiable, Notification $notification): void
    {
        if (! $notifiable instanceof Utilisateur || ! method_exists($notification, 'toPush') || ! $this->firebase->configure()) {
            return;
        }
        $m = $notification->toPush($notifiable);
        if ($m === null) {
            return;
        }
        // Relus à chaque fois : un réglage a pu changer depuis le chargement du membre.
        foreach ($notifiable->appareilsPush()->get() as $appareil) {
            if ($appareil->accepte($m['preference'])) {
                EnvoyerPush::dispatch($appareil->id, $m['titre'], $m['corps'], $m['donnees'], $m['image'] ?? null);
            }
        }
    }
}
