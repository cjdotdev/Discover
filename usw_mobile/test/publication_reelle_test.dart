// La publication telle que le serveur de production l a donnee (25 octobre 2026) : une
// image tres haute (ratio 0,457), declaree, dans un lieu cree par la publication (IFRI-UAC)
// et absent de l accueil du telephone. Ouverte depuis la notification, sa page etait noire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usw/app.dart';
import 'package:usw/donnees/catalogue.dart';
import 'package:usw/donnees/session.dart';
import 'package:usw/outils/chemins.dart';
import 'package:usw/outils/api.dart';

import 'parcours_test.dart' show avancer;
import 'serveur_simule.dart';

const _id = '01m5t4gxaeq3krdv3aavsgbz87';
const _medias = 'https://medias.discover.simeonamoussou.com/contenus/$_id';

final _publication = <String, dynamic>{
  'id': _id,
  'type': 'photo',
  'badge': 'declaree',
  'titre': null,
  'legende': null,
  'duree': null,
  'son': null,
  'ratio': 0.457,
  'publie_le': '2026-10-25T18:18:04+00:00',
  'auteur': {'id': '01m5qkk3z312n9kjkty2nzs4r4', 'nom_utilisateur': 'simeon', 'nom_affiche': 'Siméon Céphas AMOUSSOU', 'avatar': null},
  'nom_lieu': null,
  'lieu': {'id': 'ifri-uac', 'nom': 'IFRI-UAC', 'region': 'Atlantique, Bénin', 'latitude': 6.412802, 'longitude': 2.344611, 'situe': true},
  'capture': {
    'source': 'declaree',
    'telephone': 'Tecno Camon 50 Pro',
    'prise_le': '2026-10-15T10:50:00+00:00',
    'latitude': null,
    'longitude': null,
    'origines': {'modele': 'declaree', 'date': 'exif', 'position': 'declaree'},
  },
  'images': {
    '1080': {'url': '$_medias/1080.webp', 'largeur': 494, 'hauteur': 1080},
    '2160': {'url': '$_medias/2160.webp', 'largeur': 987, 'hauteur': 2160},
    '3840': {'url': '$_medias/3840.webp', 'largeur': 1755, 'hauteur': 3840},
    '480': {'url': '$_medias/480.webp', 'largeur': 219, 'hauteur': 480},
    'flou': {'url': '$_medias/flou.webp', 'largeur': 15, 'hauteur': 32},
  },
  'compteurs': {'reactions': 0, 'commentaires': 0, 'enregistrements': 0, 'partages': 0, 'vues': 0},
};

final _lieu = <String, dynamic>{
  'id': 'ifri-uac',
  'nom': 'IFRI-UAC',
  'type': 'Autres',
  'region': 'Atlantique, Bénin',
  'ville': 'Godomey',
  'pays': 'Bénin',
  'latitude': 6.412802,
  'longitude': 2.344611,
  'situe': true,
  'nombre_contenus': 1,
  'nombre_reels': 0,
  'nombre_verifiees': 0,
  'photos': [_publication],
};

/// Le serveur simule, avec en plus cette publication et son lieu.
void _brancherAvecLaPublication() {
  brancher();
  final simule = Api.simulateur!;
  Api.simulateur = (methode, chemin, corps) async {
    final p = Uri.parse(chemin).path;
    if (methode == 'GET' && p == 'contenus/$_id') return Reponse(200, {'data': _publication});
    if (methode == 'GET' && p == 'lieux/ifri-uac') return Reponse(200, {'data': _lieu});
    if (methode == 'GET' && p == 'lieux/ifri-uac/contenus') {
      return Reponse(200, {
        'data': [_publication],
        'meta': {'next_cursor': null},
      });
    }
    return simule(methode, chemin, corps);
  };
}

void main() {
  for (final depart in ['/accueil/lieu/ifri-uac/photo/$_id', '/accueil/lieu/_/photo/$_id']) {
    testWidgets('La publication réelle s ouvre depuis la notification : $depart', (tester) async {
      tester.view.physicalSize = const Size(412 * 3, 915 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      addTearDown(debrancher);
      await Session.instance.deconnecter();
      await connecterEssai();
      _brancherAvecLaPublication();
      await Catalogue.instance.rafraichir();
      await tester.pumpWidget(AppUsw(depart: depart));
      await avancer(tester, 3000);
      expect(tester.takeException(), isNull);
      expect(find.text('Tecno Camon 50 Pro'), findsWidgets);
      expect(find.text('Cette photo n’est plus disponible'), findsNothing);
    });
  }

  testWidgets('La publication s ouvre par-dessus la page des notifications (le vrai parcours)', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    addTearDown(debrancher);
    await Session.instance.deconnecter();
    await connecterEssai();
    _brancherAvecLaPublication();
    await Catalogue.instance.rafraichir();
    // Comme sur le telephone : le lieu est deja connu (l accueil l a montre).
    await Catalogue.instance.chargerLieu('ifri-uac');
    expect(Catalogue.instance.lieu('ifri-uac'), isNotNull);
    // Comme sur le telephone : l accueil, la cloche, puis la notification.
    await tester.pumpWidget(const AppUsw(depart: '/accueil'));
    await avancer(tester, 1500);
    GoRouter.of(tester.element(find.byType(Scaffold).last)).push('/notifications');
    await avancer(tester, 1500);
    // Le chemin que la notification ouvre (ici, sous /notifications).
    final routeur = GoRouter.of(tester.element(find.byType(Scaffold).last));
    // Le chemin tel que la notification le calcule, depuis sa page.
    final chemin = ici(tester.element(find.text('Notifications').first), 'lieu/ifri-uac/photo/$_id');
    expect(chemin, '/notifications/lieu/ifri-uac/photo/$_id');
    // Une feuille (hors des pages) ouverte la : la page du dessus decide aussi.
    expect(ici(tester.element(find.byType(Overlay).first), 'createur/simeon'), '/notifications/createur/simeon');
    routeur.push(chemin);
    await avancer(tester, 3000);
    expect(tester.takeException(), isNull);
    expect(find.text('Tecno Camon 50 Pro'), findsWidgets);
    // Retour : la liste des notifications, pas l accueil.
    routeur.pop();
    await avancer(tester, 1500);
    expect(tester.takeException(), isNull);
    expect(find.text('Notifications'), findsWidgets);
  });
}
