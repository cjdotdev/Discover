import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'donnees/equipe.dart';
import 'outils/etiquettes.dart';
import 'donnees/catalogue.dart';
import 'donnees/communaute.dart';
import 'donnees/envois.dart';
import 'donnees/lifestyle.dart';
import 'donnees/mes_publications.dart';
import 'donnees/push.dart';
import 'donnees/session.dart';
import 'donnees/telechargements.dart';
import 'ecrans/creer.dart';
import 'outils/images_reseau.dart';
import 'outils/mesure.dart';
import 'donnees/affichage.dart';
import 'outils/photo_profil.dart';
import 'outils/reprise.dart';
import 'outils/capacites.dart';
import 'outils/langue.dart';
import 'outils/reseau.dart';
import 'outils/sobriete.dart';
import 'widgets/lentille.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // L application dessine sous les barres du systeme, sur son fond lavande.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  lancerMesure();
  // Un telephone reste en portrait (comme WhatsApp) : tourner l ecran
  // recreait la surface de dessin, d ou un ecran noir. Une tablette tourne.
  final vue = WidgetsBinding.instance.platformDispatcher.views.first;
  if (vue.physicalSize.shortestSide / vue.devicePixelRatio < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  // Le verre liquide se charge pendant l ouverture ; la barre l attend.
  chargerLentille();
  await Affichage.instance.charger();
  await chargerPhotoProfil();
  // Deja connecte sur ce telephone : USW s ouvre sur l accueil.
  await Langue.instance.charger();
  await Session.instance.charger();
  // Les notifications sur le telephone (Firebase) : les reglages gardes, puis l ecoute.
  await Push.instance.charger();
  Push.instance.demarrer().ignore();
  Telechargements.instance.ecouterNotifications();
  // La temperature et l economiseur de batterie : l appli s allege si besoin.
  await Sobriete.instance.demarrer();
  // Wi-Fi ou donnees mobiles, et les choix du membre pour les donnees mobiles.
  await Reseau.instance.demarrer();
  unawaited(Capacites.instance.charger());
  // Une photo prise pendant qu Android avait ferme USW ? On la reprendra.
  await chercherPriseRetrouvee();
  await chargerCreer();
  await MesPublications.instance.charger();
  Lifestyle.instance.charger().ignore();
  // Les envois laisses en route reprennent (apres une coupure, l application fermee).
  Envois.instance.charger().ignore();
  // Les lieux et les reels : la copie gardee tout de suite, puis le serveur.
  Catalogue.instance.demarrer().ignore();
  // Le compte deja connecte : qui je suis, mes collections, mes notifications non lues.
  Communaute.instance.charger().ignore();
  // Mes publications que le serveur ne connait plus (un ancien serveur) s en vont.
  MesPublications.instance.accorderAuServeur().ignore();
  // Les photos gardees sur le telephone restent sous 200 Mo.
  ImagesReseau.menage().ignore();
  // Le telephone de l equipe lit ce qu il y a sur les photos publiees avant les etiquettes
  // (la recherche « arbre » les trouvera), un peu apres l ouverture, sans gener.
  Timer(const Duration(seconds: 20), () async {
    if (await Equipe.instance.reconnue()) unawaited(Etiquettes.instance.rattraper());
  });
  runApp(const AppUsw());
}
