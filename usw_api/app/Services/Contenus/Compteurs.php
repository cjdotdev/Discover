<?php

namespace App\Services\Contenus;

use App\Enums\Badge;
use App\Models\Abonnement;
use App\Models\Capture;
use App\Models\Collection;
use App\Models\Commentaire;
use App\Models\Contenu;
use App\Models\JaimeCommentaire;
use App\Models\Lieu;
use App\Models\ModeleTelephone;
use App\Models\Reaction;
use App\Models\Son;
use App\Models\Utilisateur;
use Illuminate\Support\Facades\DB;

/**
 * Les compteurs gardés en base plutôt que recalculés à chaque affichage
 * (ARCHITECTURE.md, section 7) : les contenus publiés d'un lieu, d'un modèle de téléphone.
 */
class Compteurs
{
    public static function lieu(?int $id): void
    {
        if ($id !== null) {
            Lieu::whereKey($id)->update([
                'nombre_contenus' => Contenu::publies()->where('lieu_id', $id)->count(),
                'nombre_reels' => Contenu::publies()->where('lieu_id', $id)->reels()->count(),
                'nombre_verifiees' => Contenu::publies()->where('lieu_id', $id)->where('badge', Badge::Verifiee)->count(),
            ]);
        }
    }

    /** Les reels en ligne qui utilisent un son : le catalogue montre les plus utilisés d'abord. */
    public static function son(?int $id): void
    {
        if ($id !== null) {
            Son::whereKey($id)->update(['nombre_reels' => Contenu::publies()->where('son_id', $id)->count()]);
        }
    }

    /** Les réactions, les commentaires visibles et les enregistrements d'un contenu. */
    public static function contenu(?int $id): void
    {
        if ($id !== null) {
            Contenu::whereKey($id)->update([
                'nombre_reactions' => Reaction::where('contenu_id', $id)->count(),
                'nombre_commentaires' => Commentaire::where('contenu_id', $id)->visibles()->count(),
                'nombre_enregistrements' => DB::table('enregistrements')->where('contenu_id', $id)->count(),
            ]);
        }
    }

    /** Les « j'aime » et les réponses d'un commentaire. */
    public static function commentaire(?int $id): void
    {
        if ($id !== null) {
            Commentaire::whereKey($id)->update([
                'nombre_jaime' => JaimeCommentaire::where('commentaire_id', $id)->count(),
                'nombre_reponses' => Commentaire::where('parent_id', $id)->visibles()->count(),
            ]);
        }
    }

    public static function collection(?int $id): void
    {
        if ($id !== null) {
            Collection::whereKey($id)->update(['nombre_contenus' => DB::table('enregistrements')->where('collection_id', $id)->count()]);
        }
    }

    /** Les abonnés d'un membre et ceux qu'il suit. */
    public static function membre(?int $id): void
    {
        if ($id !== null) {
            Utilisateur::whereKey($id)->update([
                'nombre_abonnes' => Abonnement::where('createur_id', $id)->count(),
                'nombre_abonnements' => Abonnement::where('abonne_id', $id)->count(),
            ]);
        }
    }

    public static function modele(?int $id): void
    {
        if ($id !== null) {
            ModeleTelephone::whereKey($id)->update([
                'nombre_contenus' => Capture::where('modele_telephone_id', $id)->whereHas('contenu', fn ($q) => $q->publies())->count(),
            ]);
        }
    }
}
