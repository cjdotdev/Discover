<?php

namespace App\Jobs;

use App\Models\AppareilPush;
use App\Services\Push\Firebase;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use RuntimeException;

/** Une notification vers un téléphone, en file : l'action du membre n'attend pas Firebase. */
class EnvoyerPush implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public array $backoff = [10, 60];

    /** @param  array<string, string>  $donnees */
    public function __construct(
        public int $appareilId,
        public string $titre,
        public string $corps,
        public array $donnees = [],
        public ?string $image = null,
    ) {}

    public function handle(Firebase $firebase): void
    {
        $appareil = AppareilPush::find($this->appareilId);
        if ($appareil === null || ! $firebase->configure()) {
            return;
        }
        $resultat = $firebase->envoyer($appareil->jeton, $this->titre, $this->corps, $this->donnees, $this->image);
        if ($resultat === Firebase::JETON_INVALIDE) {
            $appareil->delete();
        } elseif ($resultat === Firebase::ECHEC) {
            throw new RuntimeException('Firebase n’a pas pris la notification ; nouvel essai.');
        }
    }
}
