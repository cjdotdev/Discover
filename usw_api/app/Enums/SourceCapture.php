<?php

namespace App\Enums;

enum SourceCapture: string
{
    /** Les informations sont lues dans le fichier (EXIF). */
    case Fichier = 'fichier';

    /** La prise vient d'avoir lieu, depuis l'application, avec l'appareil photo du téléphone. */
    case Appareil = 'appareil';

    /** Le membre a indiqué lui-même ce que le fichier ne disait pas. */
    case Declaree = 'declaree';
}
