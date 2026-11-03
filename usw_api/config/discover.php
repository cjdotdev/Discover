<?php

// Où vont les fichiers de Discover, et ce que le serveur garde.
return [

    // L'équipe : les adresses qui ouvrent « Gérer Discover » (la modération, les membres, les
    // chiffres). Le serveur seul en décide ; rien ne se voit sur ces comptes.
    'admins' => array_values(array_filter(array_map(
        fn (string $e) => mb_strtolower(trim($e)),
        explode(',', (string) env('ADMIN_EMAILS', '')),
    ))),

    // Le compte de service Firebase (son JSON, en clair ou en base64) : les notifications sur
    // les téléphones. Vide, elles restent dans l'application.
    'firebase' => env('FIREBASE_IDENTIFIANTS'),

    // Ce que le public voit (les tailles d'image, les vidéos, les avatars) : `public` en
    // local, `r2` en production.
    'medias' => env('DISCOVER_MEDIAS', 'public'),

    // L'original envoyé par le téléphone sert à vérifier la photo (EXIF, IA), puis il reste
    // sur le téléphone de son auteur, comme les photos de WhatsApp : le serveur ne garde que
    // les tailles servies (la 2 160 px suffit pour l'écran et le téléchargement). À `true`,
    // il est gardé sur le disque `originaux` (le seau privé `r2_prive` en production).
    'garder_originaux' => (bool) env('DISCOVER_GARDER_ORIGINAUX', false),
    'originaux' => env('DISCOVER_ORIGINAUX', 'local'),

    // Le domaine des liens partagés (discover.simeonamoussou.com/l/…, /p/…, /@…, /c/…) : ses
    // pages donnent l'aperçu du lien et ouvrent l'application sur Android.
    'domaine_public' => env('DISCOVER_DOMAINE', 'discover.simeonamoussou.com'),

    // L'adresse du support, la seule montrée au public.
    'support' => env('DISCOVER_SUPPORT', 'support@discover.simeonamoussou.com'),

    // L'application Android qui ouvre ces liens : son paquet et l'empreinte SHA-256 de la clé
    // qui la signe (keytool -list -v). Plusieurs empreintes : séparées par des virgules.
    'android' => [
        'paquet' => env('ANDROID_PAQUET', 'bj.usw'),
        'empreintes' => array_values(array_filter(array_map('trim', explode(',', (string) env(
            'ANDROID_EMPREINTES',
            '05:88:E6:08:45:8D:90:F7:CA:99:1F:28:E9:8B:04:76:7F:4E:47:90:9B:25:F5:1E:CF:D7:E7:0A:94:D9:37:CF',
        ))))),
    ],

];
