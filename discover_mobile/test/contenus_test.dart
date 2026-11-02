import 'package:discover/socle/navigation/routes.dart';
import 'package:discover/socle/navigation/routeur.dart';
import 'package:discover/socle/session/session.dart';
import 'package:discover/socle/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ouvre l'application sur une adresse, avec un téléphone de 412 × 915.
// Les reels bougent sans fin : on ne peut pas attendre qu'ils s'arrêtent (`stable: false`).
Future<GoRouter> ouvrir(WidgetTester tester, String adresse, {bool stable = true}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final routeur = creerRouteur()..go(adresse);
  await tester.pumpWidget(MaterialApp.router(theme: themeDiscover(), routerConfig: routeur));
  stable ? await tester.pumpAndSettle() : await tester.pump(const Duration(seconds: 1));
  return routeur;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.instance.charger();
  });

  testWidgets('une photo montre sa fiche de capture, et on peut l\'aimer', (tester) async {
    await ouvrir(tester, Routes.photo('ouidah-1'));
    expect(find.text('Informations de capture'), findsOneWidget);
    expect(find.text('Téléphone'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp("^J'aime")));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp("^Je n'aime plus")), findsOneWidget);
  });

  testWidgets('une photo inconnue est signalée', (tester) async {
    await ouvrir(tester, Routes.photo('inconnue'));
    expect(find.text('Photo introuvable'), findsOneWidget);
  });

  testWidgets('un commentaire envoyé s\'ajoute sous celui de l\'auteur', (tester) async {
    await ouvrir(tester, Routes.commentaires('grand-popo-0'));
    expect(find.text('48 commentaires'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Superbe endroit');
    await tester.tap(find.bySemanticsLabel(RegExp('^Envoyer')));
    await tester.pumpAndSettle();
    expect(find.text('49 commentaires'), findsOneWidget);
    expect(find.text('Vous'), findsOneWidget);
  });

  testWidgets('les reels se lisent, et le cœur aime', (tester) async {
    await ouvrir(tester, Routes.reels, stable: false);
    expect(find.text('senan.voyage'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp("^J'aime")).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel(RegExp("^Je n'aime plus")), findsOneWidget);
  });

  testWidgets('la carte ouvre l\'aperçu d\'un lieu, et demande la position', (tester) async {
    await ouvrir(tester, Routes.carte);
    await tester.tap(find.bySemanticsLabel(RegExp('^Collines de Dassa-Zoumé')));
    await tester.pumpAndSettle();
    expect(find.text('Voir le reel'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Ma position')));
    await tester.pumpAndSettle();
    expect(find.text('La position est désactivée'), findsOneWidget);
  });
}
