// Les problemes signales sur le telephone, verifies a chaque fois :
// la loupe des reels, le filtre de la carte, la feuille des filtres qui doit
// tenir sans defiler, le nom Discover.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usw/app.dart';
import 'package:usw/donnees/affichage.dart';
import 'package:usw/donnees/mes_publications.dart';
import 'package:usw/donnees/session.dart';

Future<void> avancer(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// Le Camon 50 Pro : 1080 × 2364 pixels, 2,75 pixels par point, barres du systeme comprises.
const camon = Size(393, 860);

/// [deconnecter] : faux quand le test a deja quitte le compte (la deconnexion vide l historique de ce telephone).
Future<void> lancer(WidgetTester tester, String depart, {Size taille = camon, bool deconnecter = true}) async {
  tester.view.physicalSize = taille * 2.75;
  tester.view.devicePixelRatio = 2.75;
  tester.view.padding = const FakeViewPadding(top: 32 * 2.75, bottom: 20 * 2.75);
  tester.view.viewPadding = const FakeViewPadding(top: 32 * 2.75, bottom: 20 * 2.75);
  addTearDown(tester.view.reset);
  if (deconnecter) Session.instance.deconnecter();
  await tester.pumpWidget(AppUsw(depart: depart));
  await avancer(tester, 1500);
}

// La page du dessus (une page empilee par push ne change pas l adresse principale).
String _ou(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  // La vraie police (Wura Mi) : la police des tests, aux lettres carrees, est plus large.
  setUpAll(() async {
    final police = FontLoader('WuraMi');
    for (final f in ['WuraMi-Light', 'WuraMi', 'WuraMi-SemiBold', 'WuraMi-Bold']) {
      police.addFont(rootBundle.load('assets/polices/$f.ttf'));
    }
    await police.load();
    Affichage.instance.policeDuTelephone = false;
  });

  testWidgets('La loupe des reels ouvre la recherche dans l onglet Reels', (tester) async {
    await lancer(tester, '/reels');
    await tester.tap(find.bySemanticsLabel('Rechercher').first);
    await avancer(tester, 1200);
    expect(_ou(tester), '/reels/recherche');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Le filtre de la carte ouvre les filtres au premier appui', (tester) async {
    await lancer(tester, '/carte');
    await tester.tap(find.bySemanticsLabel('Filtres').first);
    await avancer(tester, 1200);
    // « Types de lieux » n apparait que si des lieux ont un type : la distance est toujours la.
    expect(find.text('Distance'), findsOneWidget);
    expect(_ou(tester), '/carte');
  });

  // Le Camon 50 Pro, un grand Android, un petit (Spark, Pop, Smart).
  for (final taille in const [camon, Size(412, 915), Size(360, 780)]) {
    testWidgets('La feuille des filtres tient sans défiler (${taille.width.toInt()}×${taille.height.toInt()})', (tester) async {
      await lancer(tester, '/carte', taille: taille);
      await tester.tap(find.bySemanticsLabel('Filtres').first);
      await avancer(tester, 1200);
      final defile = tester.state<ScrollableState>(find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      expect(defile.position.maxScrollExtent, 0, reason: 'il faut défiler dans la feuille des filtres');
      expect(find.textContaining('Voir '), findsOneWidget);
    });
  }

  testWidgets('L ouverture dit Let’s Discover', (tester) async {
    await lancer(tester, '/');
    await avancer(tester, 2500);
    expect(find.bySemanticsLabel('Let’s Discover'), findsOneWidget);
  });

  group('Une publication arrive au bon endroit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MesPublications.instance.liste.clear();
    });

    test('une video tournee avec Discover est un reel ; importee, elle va a l accueil', () async {
      final m = MesPublications.instance;
      await m.ajouter(photo: 'p10', lieu: 'Ouidah', appareil: 'Tecno', verifiee: true, priseAvecDiscover: true);
      await m.ajouter(
        photo: 'p11',
        video: '/nulle/part/tournee.mp4',
        dureeReel: 12,
        lieu: 'Ouidah',
        appareil: 'Tecno',
        verifiee: true,
        priseAvecDiscover: true,
      );
      await m.ajouter(photo: 'p12', video: '/nulle/part/importee.mp4', dureeReel: 20, lieu: 'Cotonou', appareil: 'Tecno', verifiee: false);
      expect(m.reels.map((r) => r.duree), [12]);
      expect(m.pourAccueil.map((p) => p.photo), ['p12', 'p10']);
    });

    // ajouter lit le fichier (son sens) : hors du temps simule des tests (runAsync).
    testWidgets('mon reel passe en tete des Reels', (tester) async {
      await Session.instance.deconnecter();
      await tester.runAsync(
        () => MesPublications.instance.ajouter(
          photo: 'p15',
          video: '/nulle/part/tournee.mp4',
          dureeReel: 9,
          lieu: 'Plage de Fidjrossè, Cotonou',
          legende: 'Mon premier reel sur Discover',
          appareil: 'Tecno Camon 50 Pro',
          verifiee: true,
          priseAvecDiscover: true,
        ),
      );
      await lancer(tester, '/reels', deconnecter: false);
      expect(find.textContaining('Mon premier reel sur Discover').hitTestable(), findsOneWidget);
    });

    testWidgets('ma photo passe en tete de l accueil', (tester) async {
      await Session.instance.deconnecter();
      await tester.runAsync(
        () => MesPublications.instance.ajouter(
          photo: 'p17',
          lieu: 'Plage de Fidjrossè, Cotonou',
          appareil: 'Tecno Camon 50 Pro',
          verifiee: true,
          priseAvecDiscover: true,
        ),
      );
      await lancer(tester, '/accueil', deconnecter: false);
      expect(find.text('Plage de Fidjrossè'), findsOneWidget);
      expect(find.text('Votre publication'), findsOneWidget);
    });
  });
}
