// Les données de démonstration de la découverte, celles de la maquette, en attendant l'API.
// Reprises de usw_mobile (donnees/demo.dart) : seulement ce que les écrans de Joël montrent.

class Lieu {
  const Lieu({
    required this.id,
    required this.nom,
    required this.region,
    required this.photos,
    required this.nombre,
    required this.ratio,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });

  final String id;
  final String nom;
  final String region;

  /// Les 4 meilleures photos, la premiere devant.
  final List<String> photos;
  final int nombre;

  /// Largeur sur hauteur de la pile.
  final double ratio;
  final String type;

  /// Le point ou « Y aller » mene, dans Maps.
  final double latitude;
  final double longitude;
  final int? distanceKm;
}

const lieuxDemo = <Lieu>[
  Lieu(
    id: 'grand-popo',
    nom: 'Plage de Grand-Popo',
    region: 'Mono, Bénin',
    photos: ['p108', 'p92', 'p12', 'p37'],
    nombre: 186,
    ratio: 3 / 4,
    type: 'Plages',
    latitude: 6.2833,
    longitude: 1.8222,
    distanceKm: 82,
  ),
  Lieu(
    id: 'kota',
    nom: 'Cascade de Kota',
    region: 'Atacora, Bénin',
    photos: ['p15', 'p28', 'p127', 'p10'],
    nombre: 97,
    ratio: 4 / 5,
    type: 'Cascades',
    latitude: 10.2667,
    longitude: 1.4333,
    distanceKm: 512,
  ),
  Lieu(
    id: 'pendjari',
    nom: 'Parc de la Pendjari',
    region: 'Atacora, Bénin',
    photos: ['p110', 'p66', 'p46', 'p116'],
    nombre: 248,
    ratio: 1,
    type: 'Savane et parcs',
    latitude: 11.05,
    longitude: 1.5,
    distanceKm: 620,
  ),
  Lieu(
    id: 'aheme',
    nom: 'Lac Ahémé, Possotomé',
    region: 'Mono, Bénin',
    photos: ['p124', 'p128', 'p74', 'p71'],
    nombre: 131,
    ratio: 3 / 4,
    type: 'Lacs et lagunes',
    latitude: 6.5167,
    longitude: 1.9833,
    distanceKm: 38,
  ),
  Lieu(
    id: 'dassa',
    nom: 'Collines de Dassa-Zoumé',
    region: 'Collines, Bénin',
    photos: ['p62', 'p54', 'p118', 'p29'],
    nombre: 74,
    ratio: 4 / 5,
    type: 'Collines',
    latitude: 7.75,
    longitude: 2.1833,
    distanceKm: 205,
  ),
  Lieu(
    id: 'ouidah',
    nom: 'Ponton de Ouidah',
    region: 'Atlantique, Bénin',
    photos: ['p77', 'p58', 'p101', 'p132'],
    nombre: 112,
    ratio: 1,
    type: 'Plages',
    latitude: 6.3256,
    longitude: 2.0886,
    distanceKm: 41,
  ),
  Lieu(
    id: 'porto-novo',
    nom: 'Rues de Porto-Novo',
    region: 'Ouémé, Bénin',
    photos: ['p57', 'p78', 'p76', 'p49'],
    nombre: 163,
    ratio: 3 / 4,
    type: 'Villes et rues',
    latitude: 6.4969,
    longitude: 2.6283,
    distanceKm: 33,
  ),
  Lieu(
    id: 'atacora',
    nom: "Sentiers de l'Atacora",
    region: 'Atacora, Bénin',
    photos: ['p17', 'p11', 'p28', 'p66'],
    nombre: 59,
    ratio: 4 / 5,
    type: 'Forêts',
    latitude: 10.3045,
    longitude: 1.3796,
    distanceKm: 540,
  ),
];

/// Une photo ou un reel publie sur un lieu (E33, E05). Le lot 2 donnera
/// GET /api/v1/lieux/{id}/publications.
class Publication {
  const Publication({
    required this.photo,
    required this.auteur,
    required this.appareil,
    this.verifiee = true,
    this.dureeReel,
  });

  /// L image (pour un reel, sa couverture).
  final String photo;
  final String auteur;

  /// Le telephone de la prise, lu dans l EXIF ou indique par l auteur.
  final String appareil;
  final bool verifiee;

  /// En secondes ; nul pour une photo.
  final int? dureeReel;

  bool get reel => dureeReel != null;
}

/// La largeur sur la hauteur de chaque photo de demonstration
/// (assets/photos/images.json).
const ratiosPhotos = <String, double>{
  'p10': 440 / 660,
  'p11': 440 / 550,
  'p12': 438 / 780,
  'p15': 440 / 660,
  'p17': 440 / 352,
  'p28': 440 / 704,
  'p29': 440 / 528,
  'p37': 440 / 352,
  'p46': 440 / 616,
  'p49': 440 / 528,
  'p54': 1,
  'p57': 440 / 352,
  'p58': 440 / 704,
  'p62': 438 / 780,
  'p66': 440 / 616,
  'p71': 440 / 550,
  'p74': 1,
  'p76': 440 / 616,
  'p77': 440 / 352,
};

const _auteurs = <(String, String)>[
  ('@senan.voyage', 'iPhone 14 Pro'),
  ('@aicha.k', 'Tecno Camon 30'),
  ('@kofi_dzi', 'Samsung Galaxy A55'),
  ('@marius.b', 'Infinix Note 40'),
  ('@ola.photo', 'Tecno Camon 50 Pro'),
  ('@hounkpe', 'Redmi Note 13'),
];

/// Les publications d un lieu : celles de la maquette pour Grand-Popo, et
/// pour les autres, ses photos puis celles de lieux voisins.
List<Publication> publicationsDe(Lieu lieu) {
  final photos = lieu.id == 'grand-popo'
      ? const ['p108', 'p92', 'p12', 'p37', 'p77', 'p74', 'p124', 'p71', 'p116']
      : [
          ...lieu.photos,
          ...lieuxDemo.where((l) => l.region == lieu.region && l.id != lieu.id).expand((l) => l.photos),
          ...lieu.photos.reversed,
        ].take(9).toList();
  return [
    for (var i = 0; i < photos.length; i++)
      Publication(
        photo: photos[i],
        auteur: _auteurs[i % _auteurs.length].$1,
        appareil: _auteurs[i % _auteurs.length].$2,
        // Un reel sur trois, comme dans la maquette (0:18, 0:31).
        dureeReel: i % 3 == 2 ? 18 + 13 * (i ~/ 3) : null,
      ),
  ];
}

/// Une publication retrouvee par son lieu et son rang : de quoi ouvrir sa page.
typedef RefPublication = (String, int);

Lieu lieuDe(String id) => lieuxDemo.firstWhere((l) => l.id == id);

Publication publicationDe(RefPublication r) => publicationsDe(lieuDe(r.$1))[r.$2];

/// Les publications du compte de demonstration (E18).
const mesPublications = <RefPublication>[
  ('grand-popo', 0),
  ('ouidah', 1),
  ('aheme', 2),
  ('porto-novo', 0),
  ('grand-popo', 4),
  ('dassa', 1),
  ('kota', 2),
  ('ouidah', 3),
];

/// Un createur (E20).
class Createur {
  const Createur({
    required this.pseudo,
    required this.nom,
    required this.bio,
    required this.ville,
    required this.abonnes,
    required this.refs,
  });

  final String pseudo;
  final String nom;
  final String bio;
  final String ville;
  final int abonnes;
  final List<RefPublication> refs;
}

const createursDemo = <Createur>[
  Createur(
    pseudo: 'senan.voyage',
    nom: 'Sènan Voyage',
    bio: 'Les cascades et les sentiers du Nord, à pied.',
    ville: 'Natitingou, Bénin',
    abonnes: 3420,
    refs: [('kota', 0), ('atacora', 0), ('pendjari', 1), ('kota', 3), ('atacora', 3), ('grand-popo', 0)],
  ),
  Createur(
    pseudo: 'aicha.k',
    nom: 'Aïcha K.',
    bio: 'Lagunes et bords de mer, au lever du jour.',
    ville: 'Ouidah, Bénin',
    abonnes: 1190,
    refs: [('aheme', 1), ('ouidah', 1), ('grand-popo', 1), ('aheme', 3)],
  ),
];

/// Le createur d un pseudo (« @aicha.k »), ou un createur general.
Createur createurDe(String pseudo) {
  final p = pseudo.replaceFirst('@', '');
  return createursDemo.where((c) => c.pseudo == p).firstOrNull ??
      Createur(
        pseudo: p,
        nom: p,
        bio: 'Des lieux du Bénin, en vraies photos.',
        ville: 'Bénin',
        abonnes: 240,
        refs: mesPublications.take(4).toList(),
      );
}
