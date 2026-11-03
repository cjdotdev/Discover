<?php

namespace App\Enums;

/** Le parcours d'un contenu (ARCHITECTURE.md, section 6.2). */
enum StatutContenu: string
{
    case Brouillon = 'brouillon';
    case Analyse = 'analyse';
    case ACompleter = 'a_completer';
    case FileHumaine = 'file_humaine';
    case Publie = 'publie';
    case Refuse = 'refuse';
}
