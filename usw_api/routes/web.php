<?php

use App\Http\Controllers\OriginalController;
use App\Http\Controllers\PartageController;
use Illuminate\Support\Facades\Route;

// Les liens partagés : un lieu, une photo ou un reel, un créateur, une collection.
Route::middleware('throttle:explorer')->group(function () {
    Route::get('/', [PartageController::class, 'accueil'])->name('partage.accueil');
    Route::get('l/{slug}', [PartageController::class, 'lieu'])->name('partage.lieu');
    Route::get('p/{ulid}', [PartageController::class, 'contenu'])->name('partage.contenu');
    Route::get('@{nom}', [PartageController::class, 'createur'])->name('partage.createur');
    Route::get('c/{ulid}', [PartageController::class, 'collection'])->name('partage.collection');
    // L'image de l'aperçu d'un lien, en JPEG (WhatsApp ne lit pas toujours le WebP).
    Route::get('apercu/{chemin}.jpg', [PartageController::class, 'apercu'])
        ->where('chemin', '(contenus/[0-9A-Za-z]{26}/[0-9a-z-]+|avatars/[0-9A-Za-z]{26}-[0-9]+)')
        ->name('partage.apercu');
});

// La politique de confidentialité et la suppression du compte, lisibles sans l'application
// (Google Play les demande).
Route::view('confidentialite', 'legal', ['titre' => 'Politique de confidentialité', 'page' => 'confidentialite'])->name('confidentialite');
Route::view('supprimer-mon-compte', 'legal', ['titre' => 'Supprimer mon compte', 'page' => 'suppression'])->name('suppression');

// Android ouvre ces liens dans l'application (App Links).
Route::get('.well-known/assetlinks.json', [PartageController::class, 'liensApplication'])->name('partage.liens');

// Le fichier original d'un contenu, par un lien signé de 10 minutes (GET api/v1/contenus/{contenu}/original).
Route::get('originaux/{contenu}', OriginalController::class)->middleware(['signed', 'throttle:explorer'])->name('originaux.telecharger');
