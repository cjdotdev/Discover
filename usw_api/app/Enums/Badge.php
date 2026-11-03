<?php

namespace App\Enums;

/** Capture vérifiée : le téléphone, la date et le lieu viennent du fichier ou de l'appareil. */
enum Badge: string
{
    case Verifiee = 'verifiee';
    case Declaree = 'declaree';
}
