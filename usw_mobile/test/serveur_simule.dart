// Un serveur Discover pour les tests : les memes reponses JSON que usw_api
// (ContenuResource, LieuResource, UtilisateurResource…), sans reseau. Les
// photos n ont pas d adresse : les ecrans montrent leurs cases vides.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usw/donnees/catalogue.dart';
import 'package:usw/donnees/communaute.dart';
import 'package:usw/donnees/session.dart';
import 'package:usw/outils/api.dart';

/// Une publication telle que GET contenus/{id} la donne.
Map<String, dynamic> contenu(
  String id, {
  String lieu = 'grand-popo',
  String nomLieu = 'Plage de Grand-Popo',
  String type = 'photo',
  String auteur = 'senan.voyage',
  String nomAuteur = 'Sènan Voyage',
  String telephone = 'iPhone 14 Pro',
  int reactions = 2140,
  String? titre,
  String? legende,
}) => {
  'id': id,
  'type': type,
  'statut': 'publie',
  'badge': 'verifiee',
  'titre': titre,
  'legende': legende ?? 'Fin d’après-midi, juste avant la marée haute.',
  'duree': type == 'reel' ? 24 : null,
  'son': 'Son d’origine',
  'ratio': 0.75,
  'publie_le': '2026-10-22T17:20:00+00:00',
  'auteur': {'id': auteur, 'nom_utilisateur': auteur, 'nom_affiche': nomAuteur, 'avatar': null},
  'lieu': {'id': lieu, 'nom': nomLieu, 'region': 'Mono, Bénin', 'latitude': 6.2833, 'longitude': 1.8222},
  'capture': {'source': 'fichier', 'telephone': telephone, 'prise_le': '2026-03-14T17:52:00+00:00', 'latitude': 6.2795, 'longitude': 1.8226, 'origines': {}},
  'images': <String, dynamic>{},
  'moi': {'reaction': null, 'enregistre': false},
  'compteurs': {'reactions': reactions, 'commentaires': 48, 'enregistrements': 12, 'partages': 3},
};

final _grandPopo = [
  contenu('gp1', titre: 'Les cocotiers de Grand-Popo'),
  contenu('gp2', auteur: 'aicha.k', nomAuteur: 'Aïcha K.', telephone: 'Tecno Camon 30', reactions: 312),
  contenu('gp3', type: 'reel', auteur: 'kofi_dzi', nomAuteur: 'Kofi D.', telephone: 'Samsung Galaxy A55', reactions: 5300),
];
final _kota = [
  contenu('k1', lieu: 'kota', nomLieu: 'Cascade de Kota', reactions: 97),
  contenu('k2', lieu: 'kota', nomLieu: 'Cascade de Kota', auteur: 'ola.photo', nomAuteur: 'Ola P.', titre: 'Ma cascade', reactions: 4),
];

/// Les collections du membre connu ; les suppressions passent ici.
final collectionsEssai = <Map<String, dynamic>>[];
final supprimes = <String>[];

Map<String, dynamic> _lieu(String id, String nom, String type, List<Map<String, dynamic>> contenus) => {
  'id': id,
  'nom': nom,
  'region': 'Bénin',
  'type': type,
  'latitude': 6.2833,
  'longitude': 1.8222,
  'nombre_contenus': contenus.length,
  'photos': contenus,
};

final _lieux = [
  _lieu('grand-popo', 'Plage de Grand-Popo', 'Plages', _grandPopo),
  _lieu('kota', 'Cascade de Kota', 'Cascades', _kota),
  for (final (id, nom, type) in const [
    ('pendjari', 'Parc de la Pendjari', 'Savane et parcs'),
    ('aheme', 'Lac Ahémé', 'Lacs et lagunes'),
    ('dassa', 'Collines de Dassa-Zoumé', 'Collines'),
    ('ouidah', 'Ponton de Ouidah', 'Plages'),
    ('porto-novo', 'Rues de Porto-Novo', 'Villes et rues'),
    ('atacora', 'Sentiers de l’Atacora', 'Forêts'),
  ])
    _lieu(id, nom, type, [contenu('$id-1', lieu: id, nomLieu: nom)]),
];

Map<String, dynamic> _membre(String email, {required bool complet}) => {
  'id': 'moi',
  'email': email,
  'nom_utilisateur': complet ? 'ola.photo' : null,
  'nom_affiche': complet ? 'Ola P.' : null,
  'bio': '',
  'pays': 'Bénin',
  'ville': 'Cotonou',
  'avatar': null,
  'profil_complete': complet,
  'admin': false,
  'types_aimes': <String>[],
  'compteurs': {'abonnes': 3, 'abonnements': 2, 'contenus': 0},
};

/// Un membre vu par l equipe (Gérer Discover).
Map<String, dynamic> membreEquipe(String pseudo, {bool suspendu = false}) => {
  'id': 'u-$pseudo',
  'nom_utilisateur': pseudo,
  'nom_affiche': 'Kofi D.',
  'email': '$pseudo@gmail.com',
  'avatar': null,
  'ville': 'Ouidah, Bénin',
  'fournisseur': 'google',
  'inscrit_le': '2026-10-01T10:00:00+00:00',
  'derniere_activite': '2026-10-24T10:00:00+00:00',
  'en_ligne': false,
  'suspendu': suspendu,
  'publications': 3,
  'signalements': 2,
  'equipe': false,
  'bio': '',
  'motif_suspension': suspendu ? 'Spam ou arnaque' : null,
  'suspendu_le': suspendu ? '2026-10-24T11:00:00+00:00' : null,
  'profil_complete': true,
};

final _dates = [for (var i = 0; i < 30; i++) DateTime(2026, 9, 25).add(Duration(days: i)).toIso8601String().substring(0, 10)];

/// L adresse d un membre deja inscrit (son profil est complet).
const emailConnu = 'ola.photo@gmail.com';

/// Branche le serveur simule ; a retirer avec [debrancher].
void brancher() {
  // Le modele du telephone (device_info) : pas de telephone ici, la reponse vient tout de suite.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/device_info'),
    (_) async => throw PlatformException(code: 'absent'),
  );
  var email = '';
  supprimes.clear();
  collectionsEssai
    ..clear()
    ..add({'id': 'c1', 'nom': 'Plages à revoir', 'secrete': false, 'nombre_contenus': 2, 'couverture': <String>[]});
  Api.simulateur = (methode, chemin, corps) async {
    final route = Uri.parse(chemin);
    final p = route.path;
    Reponse ok(Map<String, dynamic> json, [int code = 200]) => Reponse(code, json);
    switch ((methode, p)) {
      case ('GET', 'flux/decouverte'):
        return ok({
          'data': _lieux,
          'meta': {'next_cursor': null},
        });
      case ('GET', 'reels'):
        return ok({
          'data': [_grandPopo[2]],
          'meta': {'next_cursor': null},
        });
      case ('POST', 'auth/code/envoyer'):
        email = (corps?['email'] as String?) ?? '';
        return ok({'message': 'Un code est parti.'});
      case ('POST', 'auth/code'):
        final connu = email == emailConnu;
        return ok({'jeton': 'jeton-essai', 'nouveau': !connu, 'utilisateur': _membre(email, complet: connu)}, connu ? 200 : 201);
      case ('GET', 'moi'):
        return ok({'data': _membre(email, complet: email == emailConnu)});
      case ('GET', 'recherche'):
        return ok({'lieux': <Object>[], 'createurs': <Object>[], 'contenus': <Object>[]});
      case ('GET', 'notifications'):
        return ok({'data': <Object>[], 'non_lues': 0});
      case ('GET', 'collections'):
        return ok({'data': collectionsEssai});
      case ('GET', 'admin/tableau'):
        return ok({
          'jours': 30,
          'maintenant': {
            'en_ligne': 4,
            'aujourdhui': 12,
            'semaine': 40,
            'mois': 95,
            'membres': 130,
            'suspendus': 1,
            'publications': 310,
            'reels': 42,
            'a_verifier': 2,
            'signalements': 3,
          },
          'periode': {
            for (final k in ['inscriptions', 'publications', 'reactions', 'commentaires', 'signalements']) k: {'periode': 20, 'precedente': 16},
          },
          'courbes': {
            'dates': _dates,
            for (final k in ['actifs', 'inscriptions', 'publications', 'reactions', 'commentaires']) k: [for (var i = 0; i < 30; i++) i % 7],
          },
          'lieux': [
            {'id': 'grand-popo', 'nom': 'Plage de Grand-Popo', 'n': 12},
          ],
          'createurs': [
            {'nom_utilisateur': 'kofi_dzi', 'nom_affiche': 'Kofi D.', 'avatar': null, 'n': 140},
          ],
        });
      case ('GET', 'admin/membres'):
        return ok({
          'data': [membreEquipe('kofi_dzi')],
          'total': 1,
          'page': 1,
          'derniere_page': 1,
        });
      case ('GET', 'admin/membres/kofi_dzi'):
        return ok({
          'membre': membreEquipe('kofi_dzi'),
          'compteurs': {'publications': 3, 'reels': 1, 'reactions_recues': 140, 'jours_actifs': 9},
          'courbes': {
            'dates': _dates,
            'actif': [for (var i = 0; i < 30; i++) i % 3 == 0 ? 1 : 0],
            'reactions_recues': [for (var i = 0; i < 30; i++) i],
          },
          'contenus': <Object>[],
          'contenus_statuts': <String, String>{},
          'signalements': [
            {'motif': 'Spam ou arnaque', 'precision': null, 'cible': 'utilisateur', 'statut': 'ouvert', 'le': '2026-10-23T10:00:00+00:00'},
          ],
          'appareils': [
            {'nom': 'Samsung Galaxy A55', 'depuis': '2026-10-01T10:00:00+00:00', 'dernier_usage': '2026-10-24T10:00:00+00:00'},
          ],
          'messages': <Object>[],
        });
      case ('POST', 'admin/membres/kofi_dzi/suspension'):
        supprimes.add('suspension:${corps?['motif']}');
        return ok({'message': '@kofi_dzi est suspendu.', 'membre': membreEquipe('kofi_dzi', suspendu: true)});
      case ('GET', 'moderation/file'):
        return ok({
          'file': 'a_verifier',
          'totaux': {'a_verifier': 2, 'signalements': 3},
          'data': <Object>[],
          'commentaires': <Object>[],
        });
    }
    final morceaux = p.split('/');
    if (methode == 'DELETE' && morceaux.length == 2 && (morceaux[0] == 'contenus' || morceaux[0] == 'collections')) {
      supprimes.add(p);
      collectionsEssai.removeWhere((c) => c['id'] == morceaux[1]);
      return ok({}, 204);
    }
    if (methode == 'GET' && morceaux.length == 2 && morceaux[0] == 'lieux') {
      return ok({'data': _lieux.firstWhere((l) => l['id'] == morceaux[1], orElse: () => throw const ErreurApi(404, 'Introuvable.'))});
    }
    if (methode == 'GET' && morceaux.length == 3 && morceaux[0] == 'lieux' && morceaux[2] == 'contenus') {
      final l = _lieux.where((l) => l['id'] == morceaux[1]).firstOrNull;
      return ok({
        'data': l?['photos'] ?? <Object>[],
        'meta': {'next_cursor': null},
      });
    }
    if (methode == 'GET' && morceaux.length == 2 && morceaux[0] == 'contenus') {
      final c = [..._grandPopo, ..._kota].where((c) => c['id'] == morceaux[1]).firstOrNull;
      if (c == null) throw const ErreurApi(404, 'Introuvable.');
      return ok({'data': c});
    }
    // Le reste (commentaires, collections, abonnements…) : des listes vides.
    return ok({'data': <Object>[]});
  };
}

/// Le serveur simule, et le membre connu deja connecte (apercus, audit).
Future<void> connecterEssai() async {
  brancher();
  await Session.instance.demanderCode(emailConnu);
  await Session.instance.ouvrir(await Api.instance.post('auth/code', {'email': emailConnu, 'code': '481937'}));
  await Catalogue.instance.rafraichir();
}

void debrancher() {
  Api.simulateur = null;
  Catalogue.instance.oublier();
  Communaute.instance.oublier();
}
