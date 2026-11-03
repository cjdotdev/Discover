<?php

return [

    // Le ré-encodage des reels (B34) : sans ffmpeg, la vidéo est servie telle qu'envoyée.
    'ffmpeg' => [
        'chemin' => env('FFMPEG'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // Se connecter avec Google : les identifiants clients OAuth de Discover (Android, web), séparés par
    // des virgules. Vide tant que le projet Google Cloud n'est pas créé : la connexion Google refuse.
    'google' => [
        'client_ids' => env('GOOGLE_CLIENT_IDS', ''),
    ],

    // Chercher un lieu par son nom (Places API, New) : une clé restreinte à cette API. Vide, la
    // recherche ne trouve que les lieux de Discover.
    // L'IA de Discover (Cloudflare Workers AI, dossier ia/) : la description de ce qu'on voit.
    'ia' => [
        'url' => env('IA_URL', 'https://discover-ia.amoussoucephas34.workers.dev'),
    ],

    'google_places' => [
        'cle' => env('GOOGLE_PLACES', ''),
    ],

];
