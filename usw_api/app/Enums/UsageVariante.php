<?php

namespace App\Enums;

enum UsageVariante: string
{
    case Flou = 'flou';
    case Petite = '480';
    case Ecran = '1080';
    case Grande = '2160';
    case TresGrande = '3840';
    case Video = 'video';
    case VideoHd = 'video-1080';
    // L'aperçu d'un reel dans les grilles : 640 px, sans son, léger.
    case VideoApercu = 'video-640';
    case Affiche = 'affiche';
}
