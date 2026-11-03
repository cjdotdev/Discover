<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Throwable;

/** Le code à 6 chiffres, seul, lisible d'un coup d'œil (envoyé par Resend). */
class CodeParEmail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(public string $code, public string $but = 'connexion') {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: __(':code : votre code Discover', ['code' => $this->code]));
    }

    public function content(): Content
    {
        $intro = $this->but === 'changement'
            ? __('Voici votre code pour confirmer votre nouvelle adresse sur Discover.')
            : __('Voici votre code pour vous connecter à Discover.');

        return new Content(view: 'mails.code', text: 'mails.code-texte', with: ['logo' => self::logo(), 'intro' => $intro]);
    }

    /**
     * Le logo de l'e-mail (public/marque/discover.png), servi par le disque des médias
     * (R2 en production) : posé là la première fois. L'adresse est recalculée à chaque
     * envoi, pour suivre le domaine des médias (R2_URL) s'il change.
     */
    public static function logo(): ?string
    {
        try {
            $disque = Storage::disk(config('discover.medias'));
            Cache::rememberForever('mail.logo.pose', function () use ($disque) {
                if (! $disque->exists('marque/discover.png')) {
                    $disque->put('marque/discover.png', file_get_contents(public_path('marque/discover.png')), 'public');
                }

                return true;
            });

            return $disque->url('marque/discover.png');
        } catch (Throwable) {
            return null;
        }
    }
}
