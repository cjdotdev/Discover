import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usw/app.dart';
import 'package:usw/donnees/catalogue.dart';
import 'package:usw/donnees/communaute.dart';
import 'package:usw/donnees/session.dart';
import 'package:usw/widgets/verre.dart';

import 'serveur_simule.dart';

/// Avance de `ms` millisecondes, image par image, sans attendre les
/// animations qui tournent en continu (piles, mosaique).
Future<void> avancer(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> lancer(WidgetTester tester, [String depart = '/', bool connecte = false]) async {
  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  brancher();
  addTearDown(debrancher);
  await Session.instance.deconnecter();
  Session.instance.bienvenueVue = false;
  if (connecte) await connecterEssai();
  await Catalogue.instance.rafraichir();
  await tester.pumpWidget(AppUsw(depart: depart));
}

void main() {
  testWidgets("L'ouverture mène à la bienvenue, puis à l'entrée", (tester) async {
    await lancer(tester);
    await avancer(tester, 6000);
    expect(find.text('Suivant'), findsOneWidget);
    await tester.tap(find.text('Passer'));
    await avancer(tester, 1500);
    expect(find.text('Continuer avec Google'), findsOneWidget);
  });

  testWidgets('Au lancement suivant, l ouverture mène droit à l entrée, sans la bienvenue', (tester) async {
    await lancer(tester);
    Session.instance.bienvenueVue = true;
    await avancer(tester, 6500);
    expect(find.text('Suivant'), findsNothing);
    expect(find.text('Continuer avec Google'), findsOneWidget);
  });

  testWidgets('Connecté, l ouverture mène à l accueil', (tester) async {
    await lancer(tester);
    await connecterEssai();
    Session.instance.bienvenueVue = true;
    await avancer(tester, 6500);
    expect(find.text('Plage de Grand-Popo'), findsOneWidget);
  });

  testWidgets('Un e-mail connu entre avec le code, sans mot de passe', (tester) async {
    await lancer(tester, '/entree');
    await avancer(tester, 1500);
    await tester.enterText(find.byType(TextField), emailConnu);
    await tester.tap(find.text('Continuer'));
    await avancer(tester, 1500);
    expect(find.text('Vérifiez votre e-mail'), findsOneWidget);
    expect(find.textContaining('mot de passe'), findsNothing);
    await tester.enterText(find.byType(TextField), '481937');
    await avancer(tester, 1500);
    expect(find.text('Plage de Grand-Popo'), findsOneWidget);
  });

  testWidgets('Un e-mail inconnu crée le compte avec le code, puis complète le profil', (tester) async {
    await lancer(tester, '/entree');
    await avancer(tester, 1500);
    await tester.enterText(find.byType(TextField), 'nouveau.membre@gmail.com');
    await tester.tap(find.text('Continuer'));
    await avancer(tester, 1500);
    expect(find.text('Vérifiez votre e-mail'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '481937');
    await avancer(tester, 1500);
    expect(find.text('Étape 1 sur 3'), findsOneWidget);
  });

  testWidgets('Sans serveur, l accueil le dit et propose de réessayer', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    addTearDown(debrancher);
    await Session.instance.deconnecter();
    await Catalogue.instance.rafraichir();
    await tester.pumpWidget(const AppUsw(depart: '/accueil'));
    await avancer(tester, 1500);
    expect(find.text('Aucune connexion'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets("L'accueil montre les lieux, et son en-tête se range au défilement", (tester) async {
    await lancer(tester, '/accueil');
    await avancer(tester, 2000);
    expect(find.text('Plage de Grand-Popo'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    // Descendre range l en-tete ; remonter le fait revenir.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await avancer(tester, 800);
    expect(find.bySemanticsLabel('Rechercher').hitTestable(), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 120));
    await avancer(tester, 800);
    expect(find.bySemanticsLabel('Rechercher').hitTestable(), findsOneWidget);
  });

  testWidgets('Une pile ouvre son lieu, avec « Y aller »', (tester) async {
    await lancer(tester, '/accueil');
    await avancer(tester, 2000);
    await tester.tap(find.text('Plage de Grand-Popo'));
    await avancer(tester, 1500);
    expect(find.text('Y aller'), findsOneWidget);
    expect(find.text('@senan.voyage'), findsWidgets);
    expect(find.bySemanticsLabel('Capture vérifiée'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Retour'));
    await avancer(tester, 1500);
    expect(find.text('Y aller'), findsNothing);
  });

  testWidgets('Une photo ouverte par son identifiant montre sa fiche de capture', (tester) async {
    await lancer(tester, '/accueil/lieu/grand-popo/photo/gp1');
    await avancer(tester, 2000);
    expect(find.text('Les cocotiers de Grand-Popo'), findsOneWidget);
    expect(find.text('2,1 k'), findsOneWidget);
    await tester.ensureVisible(find.text('Informations de capture'));
    expect(find.text('iPhone 14 Pro'), findsOneWidget);
  });

  testWidgets('Une publication sans lieu connu s ouvre par la publication (notification, profil)', (tester) async {
    await lancer(tester, '/accueil/lieu/_/photo/gp2');
    await avancer(tester, 2000);
    expect(find.text('Tecno Camon 30'), findsWidgets);
    expect(find.text('Cette photo n’est plus disponible'), findsNothing);
  });

  testWidgets('Un sans-compte qui aime est invité à se connecter', (tester) async {
    await lancer(tester, '/accueil/lieu/grand-popo/photo/gp1');
    await avancer(tester, 2000);
    await tester.tap(find.text('2,1 k'));
    await avancer(tester, 500);
    expect(find.text('Connectez-vous pour réagir.'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Appuyable && w.semantique == 'J’aime'), findsOneWidget);
  });

  testWidgets('Toucher la photo l ouvre en plein écran, avec le téléchargement', (tester) async {
    await lancer(tester, '/accueil/lieu/grand-popo/photo/gp1');
    await avancer(tester, 2000);
    expect(find.text('Capture vérifiée'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Voir la photo en plein écran'));
    await avancer(tester, 1000);
    expect(find.byWidgetPredicate((w) => w is Appuyable && w.semantique == 'Télécharger la photo'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Fermer'));
    await avancer(tester, 800);
    expect(find.byWidgetPredicate((w) => w is Appuyable && w.semantique == 'Télécharger la photo'), findsNothing);
  });

  testWidgets('Mon profil sans compte invite à se connecter', (tester) async {
    await lancer(tester, '/profil');
    await avancer(tester, 1500);
    expect(find.text('Votre profil'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    await avancer(tester, 1500);
    expect(find.text('Continuer avec Google'), findsOneWidget);
  });

  testWidgets('Les trois points sous une pile ouvrent ses options ; « Voir moins » la retire de l accueil', (tester) async {
    await lancer(tester, '/accueil');
    addTearDown(() => Catalogue.instance.masquer('grand-popo', oui: false));
    await avancer(tester, 2000);
    await tester.tap(find.bySemanticsLabel('Plus d’options').first);
    await avancer(tester, 800);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.text('Y aller'), findsOneWidget);
    expect(find.text('Signaler la photo'), findsOneWidget);
    await tester.tap(find.text('Voir moins de ce lieu'));
    await avancer(tester, 1200);
    expect(find.text('Plage de Grand-Popo'), findsNothing);
  });

  testWidgets('Ma publication se supprime depuis ses options, après confirmation', (tester) async {
    await lancer(tester, '/accueil/lieu/kota/photo/k2', true);
    await avancer(tester, 2000);
    await tester.tap(find.bySemanticsLabel('Plus d’options'));
    await avancer(tester, 800);
    // La mienne : ni enregistrer ni signaler, mais supprimer.
    expect(find.text('Signaler la photo'), findsNothing);
    await tester.tap(find.text('Supprimer la publication'));
    await avancer(tester, 1000);
    expect(find.text('Supprimer cette publication ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await avancer(tester, 1500);
    expect(supprimes, contains('contenus/k2'));
    expect(find.text('Publication supprimée.'), findsOneWidget);
  });

  testWidgets('Une collection se supprime depuis les trois points de la grille', (tester) async {
    await lancer(tester, '/profil', true);
    await Communaute.instance.chargerCollections();
    await avancer(tester, 1500);
    await tester.tap(find.text('Enregistrés'));
    await avancer(tester, 800);
    expect(find.text('Plages à revoir'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Plus d’options').last);
    await avancer(tester, 800);
    await tester.tap(find.text('Supprimer la collection'));
    await avancer(tester, 1000);
    await tester.tap(find.text('Supprimer'));
    await avancer(tester, 1500);
    expect(supprimes, contains('collections/c1'));
    expect(find.text('Plages à revoir'), findsNothing);
  });

  testWidgets('Toucher la photo de profil l agrandit ; un toucher la referme', (tester) async {
    await lancer(tester, '/profil', true);
    Session.instance.avatar = 'https://medias.discover.bj/avatars/ola.webp';
    // Le profil se redessine avec la photo du serveur (pas de photo choisie sur ce telephone).
    Session.instance.changerPhoto(null);
    await avancer(tester, 1500);
    await tester.tap(find.bySemanticsLabel('Agrandir la photo de Ola P.'));
    await avancer(tester, 800);
    expect(find.bySemanticsLabel('Fermer la photo'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Fermer la photo'));
    await avancer(tester, 800);
    expect(find.bySemanticsLabel('Fermer la photo'), findsNothing);
  });

  testWidgets('Gérer Discover : le tableau de bord, puis les membres', (tester) async {
    await lancer(tester, '/gerer', true);
    await avancer(tester, 1500);
    expect(find.text('Gérer Discover'), findsOneWidget);
    expect(find.text('Actifs aujourd’hui'), findsOneWidget);
    // L evolution sur la periode (20 contre 16 : +25 %), puis les courbes, plus bas.
    final defile = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('+25 %').first, 300, scrollable: defile);
    await tester.scrollUntilVisible(find.text('Membres actifs'), 300, scrollable: defile);
    expect(find.text('Membres actifs'), findsOneWidget);
    await tester.tap(find.text('Membres').last);
    await avancer(tester, 1200);
    expect(find.text('@kofi_dzi · Ouidah, Bénin'), findsOneWidget);
  });

  testWidgets('La fiche d un membre : son parcours, puis la suspension avec son motif', (tester) async {
    await lancer(tester, '/gerer/membre/kofi_dzi', true);
    await avancer(tester, 1500);
    expect(find.text('Kofi D.'), findsOneWidget);
    expect(find.text('Actif ces 30 derniers jours'), findsOneWidget);
    await tester.tap(find.text('Suspendre'));
    await avancer(tester, 1000);
    await tester.tap(find.text('Spam ou arnaque'));
    await avancer(tester, 400);
    await tester.tap(find.text('Suspendre').last);
    await avancer(tester, 1500);
    expect(supprimes, contains('suspension:Spam ou arnaque'));
    expect(find.text('@kofi_dzi est suspendu.'), findsOneWidget);
  });
}
