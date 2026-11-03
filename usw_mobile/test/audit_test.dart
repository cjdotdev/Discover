// L audit des boutons : chaque ecran est ouvert, puis chaque element qui se
// touche (d apres l arbre d accessibilite, comme un lecteur d ecran) est touche
// a son tour, dans une application neuve. On note ce qui se passe : un autre
// ecran, une feuille ou un message, ou rien. Le rapport liste les boutons sans
// effet et les messages d attente (« arrive au prochain lot »…).
//   AUDIT=1 flutter test test/audit_test.dart
// ecrit test/audit/rapport.txt.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usw/app.dart';
import 'package:usw/donnees/affichage.dart';

import 'serveur_simule.dart';

final _actif = Platform.environment.containsKey('AUDIT');

const _ecrans = {
  'bienvenue': '/bienvenue',
  'entree': '/entree',
  'code': '/entree/code',
  'completer-1': '/completer/1',
  'completer-2': '/completer/2',
  'completer-3': '/completer/3',
  'accueil': '/accueil',
  'recherche': '/accueil/recherche',
  'lieu': '/accueil/lieu/grand-popo',
  'photo': '/accueil/lieu/grand-popo/photo/0',
  'createur': '/accueil/createur/senan.voyage',
  'reels': '/reels',
  'carte': '/carte',
  'profil': '/profil',
  'collection': '/profil/collection/0',
  'reglages': '/profil/reglages',
  'modifier': '/profil/modifier',
  'acces': '/profil/acces',
  'bloques': '/profil/bloques',
  'notifications': '/notifications',
  'notif-reglages': '/notifications/reglages',
  'motif': '/notifications/motif',
  'autoriser': '/creer/autoriser',
  'montage': '/creer/montage',
  'completer-infos': '/creer/completer',
  'details': '/creer/details',
  'choisir-lieu': '/creer/lieu',
  'envois': '/creer/envois',
  'aide': '/document/aide',
  'regles': '/document/regles',
  'moderation': '/moderation',
  'decision': '/moderation/decision',
  'hors-ligne': '/etat/hors-ligne',
  'refusee': '/etat/refusee',
};

/// Les mots d un message d attente, a remplacer par une vraie fonction.
final _attente = RegExp(r'arrive|prochain lot|bientôt|plus tard|lot \d', caseSensitive: false);

class _Cible {
  _Cible(this.nom, this.centre);
  final String nom;
  final Offset centre;
}

Future<void> _ouvrir(WidgetTester tester, String route) async {
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: AppUsw(depart: route),
    ),
  );
  for (var t = 0; t < 1400; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tout ce qui se touche a l ecran, avec un nom lisible.
List<_Cible> _cibles(WidgetTester tester) {
  final racine = tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  final cibles = <_Cible>[];
  final dpr = tester.view.devicePixelRatio;
  void visiter(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (d.hasAction(SemanticsAction.tap) && !d.flagsCollection.isHidden) {
      var rect = n.rect;
      for (SemanticsNode? p = n; p != null; p = p.parent) {
        if (p.transform != null) rect = MatrixUtils.transformRect(p.transform!, rect);
      }
      rect = Rect.fromLTRB(rect.left / dpr, rect.top / dpr, rect.right / dpr, rect.bottom / dpr);
      final ecran = Offset.zero & tester.view.physicalSize / dpr;
      if (rect.width > 0 && ecran.contains(rect.center)) {
        final nom = [d.label, d.value, d.tooltip].where((s) => s.trim().isNotEmpty).join(' · ').replaceAll('\n', ' ');
        cibles.add(_Cible(nom.isEmpty ? '(sans nom)' : nom, rect.center));
      }
    }
    n.visitChildren((c) {
      visiter(c);
      return true;
    });
  }

  if (racine != null) visiter(racine);
  return cibles;
}

Set<String> _textes(WidgetTester tester) => {
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data != null) (e.widget as Text).data! else if ((e.widget as Text).textSpan != null) (e.widget as Text).textSpan!.toPlainText(),
  for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText(),
};

String _lieu(WidgetTester tester) {
  final e = find.byType(Scaffold).evaluate().firstOrNull;
  if (e == null) return '?';
  try {
    return GoRouter.of(e).routerDelegate.currentConfiguration.uri.toString();
  } catch (_) {
    return '?';
  }
}

void main() {
  setUpAll(() async {
    Affichage.instance.policeDuTelephone = false;
    // Les appels aux autres applications (liens, presse-papiers) : notes, pas executes.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (appel) async => true,
    );
  });

  final rapport = StringBuffer();
  final morts = <String>[];
  final attentes = <String>[];

  testWidgets('audit des boutons', skip: !_actif, (tester) async {
    tester.view.physicalSize = const Size(1080, 2364);
    tester.view.devicePixelRatio = 2.75;
    tester.view.padding = const FakeViewPadding(top: 32 * 2.75, bottom: 20 * 2.75);
    tester.view.viewPadding = const FakeViewPadding(top: 32 * 2.75, bottom: 20 * 2.75);
    addTearDown(tester.view.reset);
    final semantique = tester.ensureSemantics();
    await connecterEssai();

    for (final MapEntry(key: nom, value: route) in _ecrans.entries) {
      await _ouvrir(tester, route);
      final cibles = _cibles(tester);
      rapport.writeln('\n== $nom ($route) : ${cibles.length} éléments');
      for (var i = 0; i < cibles.length; i++) {
        await _ouvrir(tester, route);
        final avantLieu = _lieu(tester);
        final avantTextes = _textes(tester);
        final c = cibles[i];
        String issue;
        try {
          await tester.tapAt(c.centre);
          for (var t = 0; t < 1000; t += 100) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final erreur = tester.takeException();
          final apresLieu = _lieu(tester);
          final nouveaux = _textes(tester).difference(avantTextes).where((s) => s.trim().isNotEmpty).toList();
          if (erreur != null) {
            issue = 'ERREUR ${erreur.toString().split('\n').first}';
          } else if (apresLieu != avantLieu) {
            issue = '→ $apresLieu';
          } else if (nouveaux.isNotEmpty) {
            issue = '+ ${nouveaux.take(3).join(' | ')}';
          } else {
            issue = 'aucun changement visible';
          }
          final attente = nouveaux.where(_attente.hasMatch).toList();
          if (attente.isNotEmpty) attentes.add('$nom · ${c.nom} : ${attente.first}');
          if (issue == 'aucun changement visible') morts.add('$nom · ${c.nom}');
        } catch (e) {
          issue = 'ECHEC ${e.toString().split('\n').first}';
        }
        rapport.writeln('  - ${c.nom} : $issue');
      }
    }
    semantique.dispose();

    final dossier = Directory('test/audit')..createSync(recursive: true);
    File('${dossier.path}/rapport.txt').writeAsStringSync(
      'SANS EFFET VISIBLE (${morts.length})\n${morts.map((m) => '  $m').join('\n')}\n\n'
      'MESSAGES D ATTENTE (${attentes.length})\n${attentes.map((m) => '  $m').join('\n')}\n\n'
      'DETAIL$rapport',
    );
  }, timeout: const Timeout(Duration(minutes: 40)));
}
