import 'package:discover/fonctionnalites/publication/donnees/envois.dart';
import 'package:discover/socle/navigation/routes.dart';
import 'package:discover/socle/navigation/routeur.dart';
import 'package:discover/socle/session/session.dart';
import 'package:discover/socle/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ouvre l'application sur une adresse, avec un téléphone de 412 × 915.
// « Mes envois » tourne sans fin pendant une vérification : on n'attend pas qu'il s'arrête (`stable: false`).
Future<GoRouter> ouvrir(WidgetTester tester, String adresse, {bool stable = true}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final routeur = creerRouteur()..go(adresse);
  await tester.pumpWidget(MaterialApp.router(theme: themeDiscover(), routerConfig: routeur));
  stable ? await tester.pumpAndSettle() : await tester.pump(const Duration(seconds: 1));
  return routeur;
}

Future<void> toucher(WidgetTester tester, String texte) async {
  await tester.ensureVisible(find.text(texte));
  await tester.pumpAndSettle();
  await tester.tap(find.text(texte));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.instance.charger();
  });

  testWidgets('une photo prise demande les autorisations une fois, puis se publie', (tester) async {
    await ouvrir(tester, Routes.creer);
    await toucher(tester, 'Prendre une photo');
    expect(find.text('Une seule fois'), findsOneWidget);

    await toucher(tester, 'Autoriser');
    expect(find.text('Nouvelle publication'), findsOneWidget);
    expect(find.text('Vérifiée'), findsOneWidget);

    await tester.tap(find.text('Publier'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Mes envois'), findsOneWidget);
    expect(find.text('Lac Ahémé'), findsOneWidget);

    // L'envoi simulé avance avec une minuterie : on l'arrête avant la fin du test.
    Envois.instance.arreter();
  });

  testWidgets('une photo importée se complète : téléphone, date, puis lieu', (tester) async {
    await ouvrir(tester, Routes.creer);
    await toucher(tester, 'Importer de la galerie');
    expect(find.text('Ce que le fichier ne dit pas'), findsOneWidget);

    await toucher(tester, "C'est ce téléphone : Tecno Camon 50 Pro");
    await tester.enterText(find.byType(TextField).last, 'Mars 2019');
    await tester.pumpAndSettle();

    await toucher(tester, 'Indiquer');
    await toucher(tester, 'Ponton de Ouidah');
    await toucher(tester, 'Choisir ce lieu');
    expect(find.text('Ponton de Ouidah'), findsOneWidget);

    await toucher(tester, 'Continuer');
    expect(find.text('Déclarée'), findsOneWidget);
  });
}
