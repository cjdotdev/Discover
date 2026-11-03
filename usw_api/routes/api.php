<?php

use App\Http\Controllers\Api\V1\AdministrationController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CollectionController;
use App\Http\Controllers\Api\V1\CommentaireController;
use App\Http\Controllers\Api\V1\CommunauteController;
use App\Http\Controllers\Api\V1\ContenuController;
use App\Http\Controllers\Api\V1\EnvoiController;
use App\Http\Controllers\Api\V1\ExplorationController;
use App\Http\Controllers\Api\V1\GeoController;
use App\Http\Controllers\Api\V1\LangueController;
use App\Http\Controllers\Api\V1\LieuController;
use App\Http\Controllers\Api\V1\LifestyleController;
use App\Http\Controllers\Api\V1\ModeleTelephoneController;
use App\Http\Controllers\Api\V1\ModerationController;
use App\Http\Controllers\Api\V1\MoiController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\SonController;
use App\Http\Controllers\Api\V1\UtilisateurController;
use App\Http\Controllers\Api\V1\VueController;
use Illuminate\Support\Facades\Route;

// Toutes les routes sont sous /api/v1 (bootstrap/app.php). Une ligne par ressource
// (ARCHITECTURE.md, section 8) ; les limites de débit sont dans AppServiceProvider.

// Lot 0 : l'application vérifie que l'API répond.
Route::get('/etat', fn () => ['nom' => 'Discover', 'version' => 'v1'])->name('etat');

// Lot 1 : le compte.
Route::prefix('auth')->name('auth.')->group(function () {
    // Sans mot de passe : un code à 6 chiffres par e-mail, ou Google.
    Route::post('code/envoyer', [AuthController::class, 'envoyer'])->middleware('throttle:codes')->name('code.envoyer');
    Route::post('code', [AuthController::class, 'code'])->middleware('throttle:connexion')->name('code');
    Route::post('google', [AuthController::class, 'google'])->middleware('throttle:connexion')->name('google');
    Route::post('deconnexion', [AuthController::class, 'deconnexion'])->middleware('auth:sanctum')->name('deconnexion');
    Route::get('nom-libre', [MoiController::class, 'nomLibre'])->middleware(['auth:sanctum', 'throttle:30,1,nom-libre'])->name('nom-libre');
});

Route::middleware('auth:sanctum')->prefix('moi')->name('moi.')->group(function () {
    Route::get('/', [MoiController::class, 'afficher'])->name('afficher');
    Route::patch('/', [MoiController::class, 'modifier'])->name('modifier');
    Route::delete('/', [MoiController::class, 'supprimer'])->name('supprimer');
    Route::get('donnees', [MoiController::class, 'donnees'])->middleware('throttle:5,60,moi-donnees')->name('donnees');
    Route::get('envois', [MoiController::class, 'envois'])->name('envois');
    Route::get('contenus', [MoiController::class, 'contenus'])->name('contenus');
    Route::post('avatar', [MoiController::class, 'avatar'])->middleware('throttle:10,1,avatar')->name('avatar');
    Route::delete('avatar', [MoiController::class, 'retirerAvatar'])->middleware('throttle:10,1,avatar')->name('avatar.retirer');
    Route::put('push', [MoiController::class, 'push'])->middleware('throttle:30,1,push')->name('push');
    Route::delete('push', [MoiController::class, 'oublierPush'])->middleware('throttle:30,1,push-oublier')->name('push.oublier');
    Route::post('email', [MoiController::class, 'demanderEmail'])->middleware('throttle:codes')->name('email');
    Route::post('email/confirmer', [MoiController::class, 'confirmerEmail'])->middleware('throttle:connexion')->name('email.confirmer');
    Route::get('lieux', [LieuController::class, 'enregistres'])->name('lieux');
    Route::put('lieux/{lieu}', [LieuController::class, 'enregistrer'])->middleware('throttle:agir')->name('lieux.enregistrer');
    Route::delete('lieux/{lieu}', [LieuController::class, 'oublier'])->middleware('throttle:agir')->name('lieux.oublier');
    Route::put('sons/{son}', [SonController::class, 'garder'])->middleware('throttle:agir')->name('sons.garder');
    Route::delete('sons/{son}', [SonController::class, 'oublier'])->middleware('throttle:agir')->name('sons.oublier');
    Route::get('lifestyle', [LifestyleController::class, 'moi'])->name('lifestyle');
    Route::put('lifestyle', [LifestyleController::class, 'regler'])->middleware('throttle:agir')->name('lifestyle.regler');
});

// Lot 2 : les lieux et les contenus, ouverts aux visiteurs (regarder sans compte).
Route::get('lieux/proche', [LieuController::class, 'proche'])->middleware('throttle:60,1,lieux-proche')->name('lieux.proche');
Route::middleware(['auth:sanctum', 'throttle:60,1,lieux-google'])->group(function () {
    Route::get('lieux/suggestions', [LieuController::class, 'suggestions'])->middleware('throttle:places')->name('lieux.suggestions');
    Route::post('lieux/google', [LieuController::class, 'depuisGoogle'])->middleware('throttle:places')->name('lieux.google');
    Route::get('lieux/google/{id}', [LieuController::class, 'positionGoogle'])->middleware('throttle:places')->where('id', '[A-Za-z0-9_\-]+')->name('lieux.google.position');
});
Route::get('lieux/{lieu}', [LieuController::class, 'afficher'])->name('lieux.afficher');
Route::get('lieux/{lieu}/contenus', [LieuController::class, 'contenus'])->name('lieux.contenus');
Route::get('contenus/{contenu}', [ContenuController::class, 'afficher'])->name('contenus.afficher');

Route::middleware('auth:sanctum')->prefix('modeles-telephone')->name('modeles.')->group(function () {
    Route::get('/', [ModeleTelephoneController::class, 'chercher'])->name('chercher');
    Route::post('/', [ModeleTelephoneController::class, 'ajouter'])->middleware('throttle:20,1,ajouter')->name('ajouter');
});

// Les vues, par paquets (avec ou sans compte).
Route::post('vues', [VueController::class, 'enregistrer'])->middleware('throttle:60,1,vues')->name('vues');
Route::post('contenus/{contenu}/pas-interesse', [VueController::class, 'pasInteresse'])->middleware('throttle:30,1,contenus-pas-interesse')->name('contenus.pas-interesse');

// Lot 3 : publier. Le brouillon et ses envois, les morceaux, l'original par lien signé.
Route::get('contenus/{contenu}/original', [ContenuController::class, 'original'])->middleware('throttle:30,1,contenus-original')->name('contenus.original');
Route::middleware('auth:sanctum')->group(function () {
    Route::post('contenus', [ContenuController::class, 'creer'])->middleware('throttle:publier')->name('contenus.creer');
    Route::patch('contenus/{contenu}', [ContenuController::class, 'modifier'])->middleware('throttle:20,1,contenus-modifier')->name('contenus.modifier');
    Route::delete('contenus/{contenu}', [ContenuController::class, 'supprimer'])->name('contenus.supprimer');
    Route::get('contenus/{contenu}/spectateurs', [VueController::class, 'spectateurs'])->middleware('throttle:30,1,spectateurs')->name('vues.spectateurs');
    Route::post('contenus/{contenu}/verification', [ContenuController::class, 'verification'])->middleware('throttle:5,60,contenus-verification')->name('contenus.verification');

    Route::match(['head'], 'envois/{envoi}', [EnvoiController::class, 'etat'])->name('envois.etat');
    Route::patch('envois/{envoi}', [EnvoiController::class, 'morceau'])->middleware('throttle:morceaux')->name('envois.morceau');
    Route::post('envois/{envoi}/terminer', [EnvoiController::class, 'terminer'])->middleware('throttle:60,1,envois-terminer')->name('envois.terminer');
});

// Lot 4 : explorer, ouvert aux visiteurs (regarder sans compte).
Route::middleware('throttle:explorer')->group(function () {
    Route::get('flux/decouverte', [ExplorationController::class, 'decouverte'])->name('flux.decouverte');
    Route::get('flux/pres-de-moi', [ExplorationController::class, 'presDeMoi'])->name('flux.pres');
    Route::get('reels', [ExplorationController::class, 'reels'])->name('reels');
    Route::get('sons', [SonController::class, 'index'])->name('sons.index');
    Route::get('sons/{son}', [SonController::class, 'afficher'])->name('sons.afficher');
    Route::get('sons/{son}/reels', [SonController::class, 'reels'])->name('sons.reels');
    Route::get('carte', [ExplorationController::class, 'carte'])->name('carte');
    Route::get('recherche', [ExplorationController::class, 'recherche'])->name('recherche');
    Route::get('geo/pays', [GeoController::class, 'pays'])->name('geo.pays');
    Route::get('geo/pays/{code}/villes', [GeoController::class, 'villes'])->name('geo.villes');
    Route::get('langues', [LangueController::class, 'index'])->name('langues');
    Route::get('langues/{code}', [LangueController::class, 'paquet'])->name('langues.paquet');
    Route::get('utilisateurs/{nom}', [UtilisateurController::class, 'afficher'])->name('utilisateurs.afficher');
    Route::get('utilisateurs/{nom}/contenus', [UtilisateurController::class, 'contenus'])->name('utilisateurs.contenus');
    Route::get('utilisateurs/{nom}/lifestyle', [LifestyleController::class, 'deMembre'])->name('utilisateurs.lifestyle');
    Route::get('lifestyles', [LifestyleController::class, 'index'])->name('lifestyles');
});

// Lot 5 : la communauté. Lire est ouvert à tous ; agir demande un compte.
Route::middleware('throttle:explorer')->group(function () {
    Route::get('contenus/{contenu}/reactions', [CommunauteController::class, 'reactions'])->name('reactions.index');
    Route::get('contenus/{contenu}/commentaires', [CommentaireController::class, 'index'])->name('commentaires.index');
    Route::get('commentaires/{commentaire}/reponses', [CommentaireController::class, 'reponses'])->name('commentaires.reponses');
    Route::get('utilisateurs/{nom}/collections', [CollectionController::class, 'duMembre'])->name('collections.membre');
    Route::get('collections/{collection}/contenus', [CollectionController::class, 'contenus'])->name('collections.contenus');
    Route::post('contenus/{contenu}/partage', [CommunauteController::class, 'partager'])->middleware('throttle:30,1,partages')->name('partages');
});
Route::middleware(['auth:sanctum', 'throttle:agir'])->group(function () {
    // Importer un son (le son d'une vidéo, un fichier du téléphone), ou en signaler un.
    Route::post('sons', [SonController::class, 'importer'])->middleware('throttle:20,60,sons-importer')->name('sons.importer');
    Route::post('sons/{son}/signaler', [SonController::class, 'signaler'])->name('sons.signaler');
    Route::put('contenus/{contenu}/reaction', [CommunauteController::class, 'reagir'])->name('reactions.mettre');
    Route::delete('contenus/{contenu}/reaction', [CommunauteController::class, 'retirerReaction'])->name('reactions.retirer');

    Route::post('contenus/{contenu}/commentaires', [CommentaireController::class, 'creer'])->middleware('throttle:commenter')->name('commentaires.creer');
    Route::patch('commentaires/{commentaire}', [CommentaireController::class, 'modifier'])->name('commentaires.modifier');
    Route::delete('commentaires/{commentaire}', [CommentaireController::class, 'supprimer'])->name('commentaires.supprimer');
    Route::post('commentaires/{commentaire}/epingle', [CommentaireController::class, 'epingler'])->name('commentaires.epingler');
    Route::put('commentaires/{commentaire}/jaime', [CommentaireController::class, 'aimer'])->name('commentaires.aimer');
    Route::delete('commentaires/{commentaire}/jaime', [CommentaireController::class, 'nePlusAimer'])->name('commentaires.ne-plus-aimer');

    Route::put('utilisateurs/{nom}/abonnement', [CommunauteController::class, 'sAbonner'])->name('abonnements.mettre');
    Route::delete('utilisateurs/{nom}/abonnement', [CommunauteController::class, 'seDesabonner'])->name('abonnements.retirer');
    Route::get('moi/abonnements', [CommunauteController::class, 'mesAbonnements'])->name('moi.abonnements');
    Route::get('moi/blocages', [CommunauteController::class, 'mesBlocages'])->name('moi.blocages');
    Route::put('utilisateurs/{nom}/blocage', [CommunauteController::class, 'bloquer'])->name('blocages.mettre');
    Route::delete('utilisateurs/{nom}/blocage', [CommunauteController::class, 'debloquer'])->name('blocages.retirer');

    Route::get('collections', [CollectionController::class, 'index'])->name('collections.index');
    Route::post('collections', [CollectionController::class, 'creer'])->name('collections.creer');
    Route::patch('collections/{collection}', [CollectionController::class, 'modifier'])->name('collections.modifier');
    Route::delete('collections/{collection}', [CollectionController::class, 'supprimer'])->name('collections.supprimer');
    Route::put('collections/{collection}/contenus/{contenu}', [CollectionController::class, 'ajouter'])->name('collections.ajouter');
    Route::delete('collections/{collection}/contenus/{contenu}', [CollectionController::class, 'retirer'])->name('collections.retirer');

    Route::post('signalements', [CommunauteController::class, 'signaler'])->middleware('throttle:10,1,signalements')->name('signalements');

    // Lot 7 : le centre des notifications.
    Route::get('notifications', [NotificationController::class, 'index'])->name('notifications.index');
    Route::post('notifications/lues', [NotificationController::class, 'lues'])->name('notifications.lues');
    Route::delete('notifications/{id}', [NotificationController::class, 'supprimer'])->whereUuid('id')->name('notifications.supprimer');
});

// Lot 6 : la modération, pour l'équipe seule (ADMIN_EMAILS) ; 404 pour tout autre compte.
Route::middleware(['auth:sanctum', 'equipe'])->prefix('moderation')->name('moderation.')->group(function () {
    Route::get('file', [ModerationController::class, 'file'])->name('file');
    Route::post('contenus/{contenu}/decision', [ModerationController::class, 'decider'])->name('decider');
    Route::post('contenus/{contenu}/classer', [ModerationController::class, 'classer'])->name('classer');
    Route::get('a-etiqueter', [ModerationController::class, 'aEtiqueter'])->name('a-etiqueter');
    Route::put('contenus/{contenu}/etiquettes', [ModerationController::class, 'etiqueter'])->name('etiqueter');
    Route::post('commentaires/{commentaire}/masquer', [ModerationController::class, 'masquer'])->name('masquer');
    Route::post('commentaires/{commentaire}/classer', [ModerationController::class, 'classerCommentaire'])->name('commentaires.classer');
});

// « Gérer Discover » : le tableau de bord, les membres, la suspension, les messages de l'équipe.
Route::middleware(['auth:sanctum', 'equipe'])->prefix('admin')->name('admin.')->group(function () {
    Route::get('acces', [AdministrationController::class, 'acces'])->name('acces');
    Route::get('tableau', [AdministrationController::class, 'tableau'])->name('tableau');
    Route::get('membres', [AdministrationController::class, 'membres'])->name('membres');
    Route::get('membres/{nom}', [AdministrationController::class, 'fiche'])->name('fiche');
    Route::post('membres/{nom}/suspension', [AdministrationController::class, 'suspendre'])->name('suspendre');
    Route::delete('membres/{nom}/suspension', [AdministrationController::class, 'reactiver'])->name('reactiver');
    Route::post('membres/{nom}/message', [AdministrationController::class, 'message'])->middleware('throttle:30,1,message')->name('message');
    Route::get('signalements/membres', [AdministrationController::class, 'membresSignales'])->name('signalements.membres');
    Route::post('signalements/membres/{nom}/classer', [AdministrationController::class, 'classerMembre'])->name('signalements.classer');
});
