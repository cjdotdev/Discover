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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.instance.charger();
  });

  testWidgets("l'accueil montre les piles des lieux et ouvre un lieu", (tester) async {
    await ouvrir(tester, Routes.accueil);
    expect(find.text('Plage de Grand-Popo'), findsOneWidget);
    expect(find.text('186 photos'), findsOneWidget);

    await tester.tap(find.text('Plage de Grand-Popo'));
    await tester.pumpAndSettle();
    expect(find.text('Mono, Bénin · 186 photos'), findsOneWidget);
  });

  testWidgets('un lieu inconnu est signalé', (tester) async {
    await ouvrir(tester, Routes.lieu('inconnu'));
    expect(find.text('Lieu introuvable'), findsOneWidget);
  });

  testWidgets('la recherche trouve un lieu, et propose une suggestion sans résultat', (tester) async {
    await ouvrir(tester, Routes.recherche);
    expect(find.text('Des idées de voyage'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kota');
    await tester.pumpAndSettle();
    expect(find.text('Cascade de Kota'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ganvi plage');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour « Ganvi plage »'), findsOneWidget);
    expect(find.text('Lieux proches de votre recherche'), findsOneWidget);
  });

  testWidgets('les filtres comptent les lieux retenus', (tester) async {
    await ouvrir(tester, Routes.filtres);
    expect(find.text('Voir 8 lieux'), findsOneWidget);

    await tester.tap(find.text('Cascades'));
    await tester.pumpAndSettle();
    expect(find.text('Voir 1 lieu'), findsOneWidget);

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    expect(find.text('Voir 8 lieux'), findsOneWidget);
  });

  testWidgets("les notifications se groupent, et l'abonnement se bascule", (tester) async {
    await ouvrir(tester, Routes.notifications);
    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);

    await tester.tap(find.text("S'abonner"));
    await tester.pumpAndSettle();
    expect(find.text('Abonné'), findsOneWidget);
  });

  testWidgets("le profil d'un créateur s'abonne et filtre ses reels", (tester) async {
    await ouvrir(tester, Routes.createur('senan.voyage'));
    expect(find.text('Sènan Voyage'), findsOneWidget);
    expect(find.text('3 420 abonnés'), findsOneWidget);

    await tester.tap(find.text("S'abonner"));
    await tester.pumpAndSettle();
    expect(find.text('3 421 abonnés'), findsOneWidget);

    await tester.tap(find.text('Reels'));
    await tester.pumpAndSettle();
    expect(find.text('Publications'), findsOneWidget);
  });
}
