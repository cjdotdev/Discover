<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/** L'alerte envoyée à l'ancienne adresse d'un compte quand elle vient d'être remplacée. */
class AdresseChangee extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(public string $nouvelle) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: __('L’adresse de votre compte Discover a changé'));
    }

    public function content(): Content
    {
        return new Content(view: 'mails.adresse-changee', text: 'mails.adresse-changee-texte', with: [
            'logo' => CodeParEmail::logo(),
            'masquee' => self::masquer($this->nouvelle),
            'support' => config('discover.support'),
        ]);
    }

    /** « si****@gmail.com » : assez pour la reconnaître, pas pour la lire en entier. */
    public static function masquer(string $email): string
    {
        [$nom, $domaine] = array_pad(explode('@', $email, 2), 2, '');

        return mb_substr($nom, 0, 2).str_repeat('*', max(3, mb_strlen($nom) - 2)).'@'.$domaine;
    }
}
