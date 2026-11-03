// Les modeles des ecrans : un lieu, une publication, un reel, un createur,
// une collection. Le serveur les remplit (donnees/catalogue.dart).
import 'catalogue.dart';
import '../outils/langue.dart';

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
    this.situe = true,
    this.pays,
    this.nombreReels,
    this.nombreVerifiees,
  });

  /// Le meme lieu, a une autre distance (calculee depuis la position du telephone).
  Lieu aDistance(int? km) => Lieu(
    id: id,
    nom: nom,
    region: region,
    photos: photos,
    nombre: nombre,
    ratio: ratio,
    type: type,
    latitude: latitude,
    longitude: longitude,
    distanceKm: km,
    situe: situe,
    pays: pays,
    nombreReels: nombreReels,
    nombreVerifiees: nombreVerifiees,
  );

  /// Le meme lieu, avec mes publications en cours d envoi devant sa pile (leurs fichiers).
  Lieu avecDevant(List<String> miennes) => Lieu(
    id: id,
    nom: nom,
    region: region,
    photos: [...miennes, ...photos],
    nombre: nombre + miennes.length,
    ratio: ratio,
    type: type,
    latitude: latitude,
    longitude: longitude,
    distanceKm: distanceKm,
    situe: situe,
    pays: pays,
    nombreReels: nombreReels,
    nombreVerifiees: nombreVerifiees,
  );

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

  /// Faux pour la pile « Sans lieu » : pas de position, ni carte, ni « Y aller ».
  final bool situe;

  /// Le pays (« Bénin »), d apres le serveur.
  final String? pays;

  /// Combien de reels publies il a (nul : le serveur ne l a pas dit). [nombre] compte photos et reels.
  final int? nombreReels;

  /// Combien de ses publications ont le badge « Capture vérifiée » (nul : inconnu).
  final int? nombreVerifiees;
}

/// Une photo ou un reel publie sur un lieu (E33, E05).
class Publication {
  const Publication({
    required this.photo,
    required this.auteur,
    required this.appareil,
    this.verifiee = true,
    this.dureeReel,
    this.filmeeDansDiscover = false,
    this.duLifestyle = false,
    this.id,
    this.lieu,
    this.lieuNom,
    this.grande,
    this.video,
    this.titre,
    this.legende,
    this.priseLe,
    this.latitude,
    this.longitude,
    this.jaime = 0,
    this.commentaires = 0,
    this.vues = 0,
    this.nomAuteur,
    this.maReaction,
    this.enregistreParMoi = false,
    this.avatarAuteur,
    this.origines = const {},
    this.tresGrande,
    this.videoHd,
    this.videoApercu,
    this.tailles = const {},
    this.modifiableJusquAu,
  });

  /// Un reel filme avec l appareil photo de Discover : il ne se voit que dans les Reels, et
  /// s ouvre toujours dans leur lecteur (pas sur la page d une photo).
  final bool filmeeDansDiscover;

  /// Du lifestyle de son auteur : sa page la montre seule (pas avec les photos d un lieu).
  final bool duLifestyle;

  /// Mon titre et ma legende se modifient jusque-la (1 h apres la mise en ligne) ; ensuite,
  /// la publication ne peut plus que se supprimer. Nul : plus modifiable (ou pas a moi).
  final DateTime? modifiableJusquAu;

  /// Encore modifiable maintenant.
  bool get modifiable => modifiableJusquAu != null && DateTime.now().isBefore(modifiableJusquAu!);

  /// La 4K (3 840 px), quand l original etait assez grand : la visionneuse la charge au zoom.
  final String? tresGrande;

  /// La video en 1080p (nulle si la source ne depasse pas le 720p) : en Wi-Fi.
  final String? videoHd;

  /// Son apercu leger (640 px, sans son), lu dans les grilles et les piles comme sur Pinterest :
  /// quatre a la fois passent sur un reseau mobile. Nul (pas encore fait) : la 720p.
  final String? videoApercu;

  /// Les tailles servies (« 1080 », « 2160 », « 3840 ») et leurs dimensions, pour le telechargement.
  final Map<String, ({int largeur, int hauteur})> tailles;

  /// La photo de profil de l auteur.
  final String? avatarAuteur;

  /// D ou vient chaque information de la prise : modele, date, position ->
  /// exif (le fichier), appareil (l appareil photo de Discover) ou declaree (l auteur).
  final Map<String, String> origines;

  /// Ma reaction (coeur, waouh, voyage, merci) et si je l ai enregistree, d apres le serveur.
  final String? maReaction;
  final bool enregistreParMoi;

  /// Ce que le serveur en dit (nul pour une publication pas encore envoyee).
  final String? id;
  final String? lieu;
  final String? lieuNom;

  /// La taille pour l ecran (1 080 px) ; [photo] est celle des mosaiques (480 px).
  final String? grande;
  final String? video;
  final String? titre;
  final String? legende;
  final DateTime? priseLe;
  final double? latitude;
  final double? longitude;
  final int jaime;
  final int commentaires;

  /// Les vues (une par personne et par jour, au moins 2 s une photo, 3 s un reel).
  final int vues;
  final String? nomAuteur;

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

/// Les ratios des photos (largeur sur hauteur) : celles du serveur et du telephone.
final ratiosFichiers = <String, double>{};

/// La video derriere chaque affiche (une adresse, ou un fichier du telephone) : la pile la lit
/// sans le son, en boucle, quand cette affiche passe devant.
final videosDesAffiches = <String, String>{};

/// La largeur sur la hauteur d une photo, si on la connait.
double ratioDe(String photo) => ratiosFichiers[photo] ?? 0.75;

/// Les publications d un lieu, telles que le serveur les a donnees.
List<Publication> publicationsDe(Lieu lieu) => Catalogue.instance.publicationsDe(lieu);

/// Ce que la page d une photo (E05) montre en plus de la carte.
class DetailPublication {
  const DetailPublication({
    required this.titre,
    required this.legende,
    required this.priseLe,
    required this.gps,
    required this.jaime,
    required this.commentaires,
    this.vues = 0,
    required this.createur,
    required this.abonnes,
  });

  final String titre;
  final String legende;
  final String priseLe;

  /// Les coordonnees lues dans le fichier, telles qu affichees.
  final String gps;
  final int jaime;
  final int commentaires;
  final int vues;
  final String createur;
  final int abonnes;
}

// Le nom du mois (1 a 12), dans la langue choisie.
String _mois(int m) => [t('janvier'), t('février'), t('mars'), t('avril'), t('mai'), t('juin'), t('juillet'), t('août'), t('septembre'), t('octobre'), t('novembre'), t('décembre')][m - 1];

/// « 14 mars 2026, 17 h 52 ».
String dateLongue(DateTime d) {
  final l = d.toLocal();
  return t('{jour} {mois} {annee}, {heure} h {minute}', {'jour': l.day, 'mois': _mois(l.month), 'annee': l.year, 'heure': l.hour, 'minute': l.minute.toString().padLeft(2, '0')});
}

/// « 6,2795° N, 1,8226° E ».
String coordonnees(double lat, double lon) {
  String c(double v, String plus, String moins) => '${v.abs().toStringAsFixed(4).replaceAll('.', ',')}° ${v >= 0 ? plus : moins}';
  return '${c(lat, t('N'), t('S'))}, ${c(lon, t('E'), t('O'))}';
}

/// La fiche d une publication du serveur.
DetailPublication detailDuServeur(Lieu lieu, Publication p) => DetailPublication(
  titre: (p.titre ?? '').isNotEmpty ? p.titre! : lieu.nom,
  legende: p.legende ?? '',
  priseLe: p.priseLe == null ? t('Date inconnue') : dateLongue(p.priseLe!),
  gps: p.latitude == null || p.longitude == null ? t('Position inconnue') : coordonnees(p.latitude!, p.longitude!),
  jaime: p.jaime,
  commentaires: p.commentaires,
  vues: p.vues,
  createur: p.nomAuteur ?? p.auteur,
  abonnes: 0,
);

/// « 1 vue », « 2,1 k vues ».
String vuesLisibles(int n) => n == 1 ? t('1 vue') : t('{nombre} vues', {'nombre': nombreCourt(n)});

/// Un nombre court : 2140 -> « 2,1 k ».
String nombreCourt(int n) => n < 1000 ? '$n' : '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} k';

/// Les types de lieux de « Compléter le profil », etape 3, et des filtres. Envoyes au
/// serveur tels quels : on les traduit seulement a l affichage (typeLisible).
/// Les gouts proposes a l inscription : ce qu on aime voir sur les photos. Le serveur les relie a
/// ce que le telephone voit sur chaque photo (Google ML Kit). Chacun a sa photo libre de droits
/// (CC0, StockSnap), livree avec l application : elle s affiche tout de suite, meme hors connexion.
const themesAimes = <({String cle, String nom})>[
  (cle: 'nature', nom: 'Nature'),
  (cle: 'paysages', nom: 'Paysages'),
  (cle: 'mer', nom: 'Mer et plages'),
  (cle: 'nourriture', nom: 'Nourriture'),
  (cle: 'architecture', nom: 'Immeubles et architecture'),
  (cle: 'animaux', nom: 'Animaux'),
  (cle: 'fleurs', nom: 'Fleurs'),
  (cle: 'ville', nom: 'En ville'),
  (cle: 'couchers', nom: 'Couchers de soleil'),
  (cle: 'cascades', nom: 'Cascades et rivières'),
  (cle: 'culture', nom: 'Culture et patrimoine'),
  (cle: 'fetes', nom: 'Fêtes et musique'),
];

const typesDeLieux = <String>['Plages', 'Cascades', 'Savane et parcs', 'Lacs et lagunes', 'Villes et rues', 'Collines', 'Forêts', 'Couchers de soleil', 'Patrimoine'];

/// Le nom affiche d un type de lieu, dans la langue choisie ; un type inconnu reste tel quel.
String typeLisible(String type) => switch (type) {
  'Plages' => t('Plages'),
  'Cascades' => t('Cascades'),
  'Savane et parcs' => t('Savane et parcs'),
  'Lacs et lagunes' => t('Lacs et lagunes'),
  'Villes et rues' => t('Villes et rues'),
  'Collines' => t('Collines'),
  'Forêts' => t('Forêts'),
  'Couchers de soleil' => t('Couchers de soleil'),
  'Patrimoine' => t('Patrimoine'),
  'Autres' => t('Autres'),
  _ => type,
};

/// Le lieu d un reel : un lieu connu, ou celui que son auteur a indique.
Lieu lieuDuReel(Reel r) =>
    Catalogue.instance.lieu(r.lieu) ??
    Lieu(
      id: r.lieu,
      nom: r.lieuNom ?? t('Lieu indiqué'),
      region: '',
      photos: [r.photo],
      nombre: 1,
      ratio: 9 / 16,
      type: '',
      latitude: r.latitude ?? 0,
      longitude: r.longitude ?? 0,
      distanceKm: r.mien ? 0 : null,
      // Sans position connue : ni carte, ni « Y aller » (il menait au point 0, 0).
      situe: r.latitude != null && r.longitude != null,
    );

/// Une collection d enregistrements (E19), secrete ou non.
class Collection {
  const Collection({required this.id, required this.nom, this.secrete = false, required this.nombre, this.photos = const []});

  final String id;

  /// Les photos de sa couverture.
  final List<String> photos;

  final String nom;
  final bool secrete;
  final int nombre;
}

/// Un createur (E20).
class Createur {
  const Createur({required this.pseudo, required this.nom, required this.bio, required this.ville, required this.abonnes, this.publications, this.avatar, this.nombre, this.site, this.lifestyle = 0});

  /// Les publications de son lifestyle, s il l a rendu visible (0 : pas de lifestyle a voir).
  final int lifestyle;

  /// Son site web (vide ou nul : aucun).
  final String? site;

  /// Ses publications, telles que le serveur les donne (nul : pas encore arrivees).
  final List<Publication>? publications;
  final String? avatar;
  final int? nombre;

  final String pseudo;
  final String nom;
  final String bio;
  final String ville;
  final int abonnes;
}

/// Un reel (E06) : sa video, et sa couverture en attendant.
class Reel {
  const Reel({
    required this.photo,
    required this.pseudo,
    required this.nom,
    required this.legende,
    required this.appareil,
    required this.lieu,
    required this.duree,
    required this.jaime,
    required this.commentaires,
    required this.enregistres,
    required this.partages,
    this.vues = 0,
    this.son = "Son d'origine",
    this.video,
    this.lieuNom,
    this.latitude,
    this.longitude,
    this.mien = false,
    this.id,
    this.maReaction,
    this.verifiee = false,
    this.avatar,
    this.videoHd,
    this.musiqueId,
    this.musiqueActive = true,
  });

  /// La musique du catalogue posee sur le reel : sa page (les reels qui l utilisent, « Utiliser ce son »).
  final String? musiqueId;

  /// Toujours dans le catalogue : « Utiliser ce son » est possible.
  final bool musiqueActive;

  /// La video en 1080p, lue en Wi-Fi sur un telephone qui la porte ([video] reste la 720p).
  final String? videoHd;

  /// Le badge du serveur : « Capture vérifiée » (vrai) ou « Informations déclarées ».
  final bool verifiee;

  /// La photo de profil du createur.
  final String? avatar;

  /// Ma reaction, d apres le serveur (coeur, waouh, voyage, merci).
  final String? maReaction;

  /// Son identifiant sur le serveur (nul pour un reel pas encore envoye).
  final String? id;

  /// La video : un fichier du telephone (un reel publie d ici) ou une adresse
  /// du serveur ; sans elle, la couverture seule.
  final String? video;

  /// Un lieu que Discover ne connait pas encore : son nom et son point.
  final String? lieuNom;
  final double? latitude;
  final double? longitude;

  /// Publie par le membre, depuis ce telephone.
  final bool mien;

  final String photo;
  final String pseudo;
  final String nom;
  final String legende;
  final String appareil;
  final String lieu;
  final int duree;
  final int jaime;
  final int commentaires;
  final int enregistres;
  final int partages;
  final int vues;
  final String son;

  /// Le son a afficher : « Son d origine » se traduit, un vrai titre reste tel quel.
  String get sonLisible => aUneMusique ? son : t("Son d'origine");

  /// Une vraie musique posee sur le reel (pas le son d origine) : son disque tourne, son titre s affiche.
  bool get aUneMusique => musiqueId != null || (son.trim().isNotEmpty && son != "Son d'origine" && son != 'Son d’origine');
}
