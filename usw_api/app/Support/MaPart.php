<?php

namespace App\Support;

use App\Models\Contenu;
use App\Models\Reaction;
use App\Models\Utilisateur;
use Illuminate\Support\Facades\DB;

/**
 * Ce que le membre connecté a fait des photos d'une page gardée en cache (l'accueil) : la page
 * est la même pour tous, sa réaction et ses enregistrements s'y ajoutent à chaque requête.
 * Sans cela, l'application ignorait qu'il avait déjà aimé une photo et comptait son cœur deux fois.
 */
class MaPart
{
    /**
     * @param  array<int, array<string, mixed>>  $lieux  des LieuResource résolus (avec leurs « photos »)
     * @return array<int, array<string, mixed>>
     */
    public static function dansLesLieux(array $lieux, ?Utilisateur $u): array
    {
        if ($u === null) {
            return $lieux;
        }
        $ulids = [];
        foreach ($lieux as $l) {
            foreach ($l['photos'] ?? [] as $p) {
                $ulids[] = $p['id'];
            }
        }
        if ($ulids === []) {
            return $lieux;
        }
        $ids = Contenu::whereIn('ulid', $ulids)->pluck('id', 'ulid');
        $reactions = Reaction::where('utilisateur_id', $u->id)->whereIn('contenu_id', $ids->values())->pluck('type', 'contenu_id');
        $enregistres = DB::table('enregistrements')
            ->join('collections', 'collections.id', '=', 'enregistrements.collection_id')
            ->where('collections.utilisateur_id', $u->id)
            ->whereIn('enregistrements.contenu_id', $ids->values())
            ->distinct()->pluck('enregistrements.contenu_id')->flip();
        foreach ($lieux as $i => $l) {
            foreach ($l['photos'] ?? [] as $j => $p) {
                $id = $ids[$p['id']] ?? null;
                $lieux[$i]['photos'][$j]['moi'] = [
                    'reaction' => $id === null ? null : ($reactions[$id] ?? null),
                    'enregistre' => $id !== null && isset($enregistres[$id]),
                ];
            }
        }

        return $lieux;
    }
}
