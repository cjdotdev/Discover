<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Contenus\AjouterModele;
use App\Http\Requests\Contenus\ChercherModeles;
use App\Http\Resources\ModeleTelephoneResource;
use App\Models\ModeleTelephone;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Les modèles de téléphone (E15 : indiquer le téléphone quand le fichier ne le dit pas). */
class ModeleTelephoneController extends Controller
{
    /** GET modeles-telephone?q= : par le début de la marque ou du nom ; les plus utilisés d'abord. */
    public function chercher(ChercherModeles $requete): AnonymousResourceCollection
    {
        $q = ModeleTelephone::normaliser($requete->validated('q'));
        $nom = ModeleTelephone::query()
            ->where(fn ($r) => $r->where('nom_recherche', 'like', str_replace(['%', '_'], '', $q).'%')->orWhere('nom_recherche', 'like', '% '.str_replace(['%', '_'], '', $q).'%'))
            ->orderByDesc('nombre_contenus')->orderBy('nom_recherche')
            ->limit(10)
            ->get();

        return ModeleTelephoneResource::collection($nom);
    }

    /** POST modeles-telephone */
    public function ajouter(AjouterModele $requete): JsonResponse
    {
        $modele = ModeleTelephone::create([...$requete->validated(), 'ajoute_par' => $requete->user()->id]);

        return (new ModeleTelephoneResource($modele))->response()->setStatusCode(201);
    }
}
