<?php

namespace App\Enums;

enum RoleEnvoi: string
{
    /** L'image légère (WebP de 2 160 px au plus) : elle part d'abord, elle suffit à publier une photo. */
    case Apercu = 'apercu';

    /** Le fichier tel que le téléphone l'a fait : la photo pleine taille, ou la vidéo d'un reel. */
    case Original = 'original';
}
