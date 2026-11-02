import 'package:discover/fonctionnalites/compte/donnees/mot_de_passe_regles.dart';
import 'package:discover/socle/navigation/routes.dart';
import 'package:discover/socle/navigation/routeur.dart';
import 'package:discover/socle/session/session.dart';
import 'package:discover/socle/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ouvre l'application sur une adresse, avec un téléphone de 412 × 915.
Future<GoRouter> ouvrir(WidgetTester tester, String adresse) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final routeur = creerRouteur()..go(adresse);
  await tester.pumpWidget(MaterialApp.router(theme: themeDiscover(), routerConfig: routeur));
  await tester.pumpAndSettle();
  return routeur;
}

Future<void> toucher(WidgetTester tester, String texte) async {
  await tester.ensureVisible(find.text(texte));
  await tester.pumpAndSettle();
  await tester.tap(find.text(texte));
  await tester.pumpAndSettle();
}

// Attend la réponse simulée (300 ms) et la fin de la transition.
Future<void> attendre(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.instance.charger();
  });

  test('les règles du mot de passe', () {
    expect(ReglesMotDePasse.valide('Discover1'), isTrue);
    expect(ReglesMotDePasse.valide('court1'), isFalse);
    expect(ReglesMotDePasse.valide('sanschiffre'), isFalse);
    expect(ReglesMotDePasse.valide('12345678'), isFalse);
  });

  test('la première page dépend de la session', () async {
    expect(Session.instance.destination, Routes.bienvenue);

    await Session.instance.marquerBienvenueVue();
    expect(Session.instance.destination, Routes.entree);

    await Session.instance.ouvrir(jeton: 'x', profilComplet: false);
    expect(Session.instance.destination, Routes.completerProfil);

    await Session.instance.marquerProfilComplet();
    expect(Session.instance.destination, Routes.accueil);
  });

  testWidgets("la bienvenue passe trois pages et mène à l'entrée", (tester) async {
    // Les pages avancent seules toutes les six secondes : on attend une seconde, pas la fin du minuteur.
    Future<void> suivant() async {
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final routeur = creerRouteur()..go(Routes.bienvenue);
    await tester.pumpWidget(MaterialApp.router(theme: themeDiscover(), routerConfig: routeur));
    await tester.pump();
    expect(find.text('Des lieux, en vraies photos'), findsOneWidget);

    await suivant();
    expect(find.text("Chaque photo dit d'où elle vient"), findsOneWidget);

    await suivant();
    expect(find.text('Explorer sans compte'), findsOneWidget);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue sur Discover'), findsOneWidget);
    expect(Session.instance.bienvenueVue, isTrue);
  });

  testWidgets('une adresse mal formée est refusée', (tester) async {
    await ouvrir(tester, Routes.entree);

    await tester.enterText(find.byType(TextField), 'pas-une-adresse');
    await toucher(tester, 'Continuer');

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
  });

  testWidgets('un compte connu se connecte, et le mauvais mot de passe est signalé', (tester) async {
    await Session.instance.marquerBienvenueVue();
    await ouvrir(tester, Routes.entree);

    await tester.enterText(find.byType(TextField), 'membre@discover.bj');
    await tester.tap(find.text('Continuer'));
    await attendre(tester);
    expect(find.text('Entrez votre mot de passe'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'faux');
    await tester.tap(find.text('Se connecter'));
    await attendre(tester);
    expect(find.textContaining('Mot de passe incorrect'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Discover1');
    await tester.tap(find.text('Se connecter'));
    await attendre(tester);
    expect(Session.instance.connecte, isTrue);
    expect(find.text('Plage de Grand-Popo'), findsOneWidget);
  });

  testWidgets('un nouveau compte crée son mot de passe, vérifie le code et complète son profil', (tester) async {
    await Session.instance.marquerBienvenueVue();
    await ouvrir(tester, Routes.entree);

    await tester.enterText(find.byType(TextField), 'nouveau@discover.bj');
    await tester.tap(find.text('Continuer'));
    await attendre(tester);
    expect(find.text('Créez votre mot de passe'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Discover1');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await attendre(tester);
    expect(find.text('Vérifiez votre e-mail'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ce code est incorrect ou a expiré.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await attendre(tester);
    expect(find.text('Votre profil'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Akouavi');
    await tester.enterText(find.byType(TextField).at(1), 'akouavi.k');
    await toucher(tester, 'Continuer');
    expect(find.text("D'où êtes-vous ?"), findsOneWidget);

    await toucher(tester, 'Continuer');
    expect(find.text('Ce que vous aimez voir'), findsOneWidget);

    await toucher(tester, 'Mer et plages');
    await toucher(tester, 'Paysages');
    expect(find.text('Encore 1'), findsOneWidget);
    await toucher(tester, 'Nature');

    await tester.tap(find.text('Terminer · 3 choisis'));
    await attendre(tester);
    expect(Session.instance.profilComplet, isTrue);
    expect(find.text('Plage de Grand-Popo'), findsOneWidget);
  });

  testWidgets('le mot de passe oublié mène au nouveau mot de passe', (tester) async {
    await ouvrir(tester, Routes.avec(Routes.oubli, {'email': 'membre@discover.bj'}));

    await tester.tap(find.text('Envoyer le code'));
    await attendre(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await toucher(tester, 'Vérifier');
    expect(find.text('Nouveau mot de passe'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'Discover2');
    await tester.enterText(find.byType(TextField).at(1), 'Discover2');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await attendre(tester);
    expect(find.text('Bienvenue sur Discover'), findsOneWidget);
  });

  testWidgets('tous les écrans à réaliser sont reliés à la navigation', (tester) async {
    const ecrans = {
      Routes.creer: 'E12',
      Routes.autorisations: 'E32',
      Routes.details: 'E14',
      Routes.completerCapture: 'E15',
      Routes.indiquerLieu: 'E30',
      Routes.enRoute: 'E16',
      Routes.profil: 'E18',
      Routes.modifierProfil: 'E21',
      Routes.reglages: 'E21',
    };
    for (final MapEntry(key: adresse, value: code) in ecrans.entries) {
      await ouvrir(tester, adresse);
      expect(find.text(code), findsOneWidget, reason: adresse);
    }
  });
}
