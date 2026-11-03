// Ce que le serveur renvoie (usw_api) devient les modeles des ecrans : une
// publication, un commentaire, une notification, une collection. Les champs
// sont ceux des ressources JSON du serveur (ContenuResource, CommentaireResource…).
import 'package:flutter_test/flutter_test.dart';
import 'package:usw/donnees/catalogue.dart';
import 'package:usw/donnees/communaute.dart';
import 'package:usw/donnees/modeles.dart';

Map<String, dynamic> _contenu({String type = 'photo'}) => {
  'id': '01m5nhatzzdekye70makffmk3y',
  'type': type,
  'badge': 'verifiee',
  'titre': null,
  'legende': 'Fin d’après-midi sur la Route des pêches.',
  'duree': type == 'reel' ? 24 : null,
  'son': 'Son d’origine',
  'ratio': 0.75,
  'publie_le': '2026-10-22T17:20:00+00:00',
  'auteur': {'id': 'x', 'nom_utilisateur': 'aicha.k', 'nom_affiche': 'Aïcha K.', 'avatar': null},
  'lieu': {'id': 'ouidah', 'nom': 'Ponton de Ouidah', 'region': 'Atlantique, Bénin', 'latitude': 6.3256, 'longitude': 2.0886},
  'capture': {
    'source': 'fichier',
    'telephone': 'Tecno Camon 50 Pro',
    'prise_le': '2026-03-14T17:52:00+00:00',
    'latitude': 6.2795,
    'longitude': 1.8226,
    'origines': {},
  },
  'images': {
    '480': {'url': 'http://localhost:8000/storage/contenus/a/480.webp', 'largeur': 360, 'hauteur': 480},
    '1080': {'url': 'http://localhost:8000/storage/contenus/a/1080.webp', 'largeur': 810, 'hauteur': 1080},
    if (type == 'reel') 'affiche': {'url': 'http://localhost:8000/storage/contenus/a/affiche.webp', 'largeur': 608, 'hauteur': 1080},
    if (type == 'reel') 'video': {'url': 'http://localhost:8000/storage/contenus/a/video.mp4', 'largeur': null, 'hauteur': null},
  },
  'moi': {'reaction': 'voyage', 'enregistre': true},
  'compteurs': {'reactions': 2140, 'commentaires': 48, 'enregistrements': 12, 'partages': 3},
};

void main() {
  tearDown(Catalogue.instance.oublier);

  test('une photo du serveur devient une publication complète', () {
    final p = Catalogue.instance.publicationsDepuis([_contenu()]).single;
    expect(p.id, '01m5nhatzzdekye70makffmk3y');
    // Les cartes prennent « 1080 » (« 480 » est flou sur une carte), la page la plus grande donnee.
    expect(p.photo, endsWith('/1080.webp'));
    expect(p.grande, anyOf(endsWith('/2160.webp'), endsWith('/1080.webp')));
    expect(p.auteur, '@aicha.k');
    expect(p.nomAuteur, 'Aïcha K.');
    expect(p.appareil, 'Tecno Camon 50 Pro');
    expect(p.verifiee, isTrue);
    expect(p.reel, isFalse);
    expect(p.lieu, 'ouidah');
    expect(p.jaime, 2140);
    expect(p.maReaction, 'voyage');
    expect(p.enregistreParMoi, isTrue);
    expect(ratioDe(p.photo), 0.75);
    // Son lieu est connu du catalogue, meme s il n est pas encore passe a l accueil.
    expect(Catalogue.instance.lieu('ouidah')?.nom, 'Ponton de Ouidah');

    final d = detailDuServeur(Catalogue.instance.lieu('ouidah')!, p);
    // A l heure du telephone : la date, et l heure telle que dateLongue l ecrit.
    expect(d.priseLe, dateLongue(DateTime.parse('2026-03-14T17:52:00+00:00')));
    expect(d.priseLe, startsWith('14 mars 2026, '));
    expect(d.gps, '6,2795° N, 1,8226° E');
    expect(d.titre, 'Ponton de Ouidah');
    expect(d.createur, 'Aïcha K.');
  });

  test('un reel du serveur garde son affiche et sa vidéo', () {
    final p = Catalogue.instance.publicationsDepuis([_contenu(type: 'reel')]).single;
    expect(p.reel, isTrue);
    expect(p.dureeReel, 24);
    expect(p.photo, endsWith('/affiche.webp'));
    expect(p.video, endsWith('/video.mp4'));
  });

  test('un commentaire, une notification et une collection du serveur', () {
    final c = CommentaireServeur.depuis({
      'id': 'c1',
      'texte': 'Au lever du jour, avant 9 h.',
      'auteur': {'nom_utilisateur': 'aicha.k', 'nom_affiche': 'Aïcha K.', 'avatar': null},
      'repond_a': {'nom_utilisateur': 'akouavi.kossou', 'nom_affiche': 'Akouavi K.'},
      'parent': 'c0',
      'epingle': false,
      'de_l_auteur': true,
      'jaime': 3,
      'reponses': 0,
      'cree_le': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'moi': {'jaime': true, 'auteur': false},
    });
    expect(c.repondA, 'Akouavi K.');
    expect(c.deLAuteur, isTrue);
    expect(c.aimeParMoi, isTrue);
    expect(ilYA(c.quand), '3 h');

    final n = NotificationServeur.depuis({
      'id': 'n1',
      'genre': 'mention',
      'texte': 'vous a mentionné dans un commentaire.',
      'acteur': {'nom_utilisateur': 'kofi', 'nom_affiche': 'Kofi D.', 'avatar': null},
      'contenu': {'id': '01m5', 'type': 'photo', 'lieu': 'ouidah', 'photo': 'http://localhost:8000/storage/contenus/a/480.webp'},
      'commentaire': 'c1',
      'lue': false,
      'cree_le': DateTime.now().toIso8601String(),
    });
    expect(n.acteur, 'Kofi D.');
    expect(n.lieu, 'ouidah');
    expect(n.lue, isFalse);

    final col = CollectionServeur.depuis({
      'id': 'k1',
      'nom': 'Plages',
      'secrete': true,
      'nombre_contenus': 2,
      'couverture': ['http://localhost:8000/storage/a.webp'],
    });
    expect(col.secrete, isTrue);
    expect(col.couverture, hasLength(1));
  });

  test('sans serveur, aucun lieu inventé', () {
    expect(Catalogue.instance.duServeur, isFalse);
    expect(Catalogue.instance.lieux, isEmpty);
    expect(Catalogue.instance.reels, isEmpty);
    // La vitrine montre les images livrees avec l application, sans lieu ni auteur.
    expect(Catalogue.instance.vitrine(3).every((p) => p.startsWith('assets/interets/')), isTrue);
    expect(Catalogue.instance.vitrine(3).toSet(), hasLength(3));
  });

  test('une publication sans lieu a un lieu a elle seule, pour ouvrir sa page', () {
    final sansLieu = {..._contenu(), 'id': 'seule', 'lieu': null};
    final p = Catalogue.instance.publicationsDepuis([sansLieu]).single;
    expect(p.lieu, isNull);
    final l = Catalogue.instance.lieuSeul(p);
    expect(publicationsDe(l).single.id, 'seule');
    expect(Catalogue.instance.lieu(l.id), same(l));
  });

  test('un commentaire retouché le dit', () {
    final c = CommentaireServeur.depuis({
      'id': 'c2',
      'texte': 'Corrigé.',
      'auteur': {'nom_utilisateur': 'ola.photo', 'nom_affiche': 'Ola P.'},
      'cree_le': DateTime.now().toIso8601String(),
      'modifie': true,
      'moi': {'jaime': false, 'auteur': true},
    });
    expect(c.modifie, isTrue);
    expect(c.mien, isTrue);
  });
}
