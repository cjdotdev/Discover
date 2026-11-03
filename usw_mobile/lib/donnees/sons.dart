// Les sons a mettre sur un reel, comme sur TikTok, Instagram, Snapchat ou WhatsApp : le
// catalogue du serveur (des musiques dont la licence permet l usage dans une application),
// mes favoris, la page d un son et les reels qui l utilisent. Le son choisi au montage part
// avec le reel : le serveur le mele a la video.
import 'dart:io';

import '../outils/api.dart';
import 'catalogue.dart';
import 'modeles.dart';

/// Un son du catalogue.
class Son {
  const Son({
    required this.id,
    required this.titre,
    required this.artiste,
    required this.categorie,
    required this.dureeMs,
    required this.url,
    this.forme = const [],
    this.debutConseilleMs = 0,
    this.attribution = '',
    this.licence = '',
    this.licenceUrl,
    this.nombreReels = 0,
    this.favori = false,
    this.actif = true,
    this.importe = false,
  });

  /// Importe par un membre (le son d une video, un fichier du telephone) : il peut etre signale.
  final bool importe;

  final String id;
  final String titre;
  final String artiste;
  final String categorie;
  final int dureeMs;
  final String url;

  /// Le dessin de l onde : 100 hauteurs, de 0 a 100.
  final List<int> forme;

  /// Le passage le plus fort, propose d abord (le refrain, souvent).
  final int debutConseilleMs;

  /// Ce que la licence demande d afficher : le titre, l auteur et la licence.
  final String attribution;
  final String licence;
  final String? licenceUrl;
  final int nombreReels;
  final bool favori;
  final bool actif;

  /// « Allada · Kevin MacLeod »
  String get nom => '$titre · $artiste';

  Son avecFavori(bool f) => Son(
    id: id,
    titre: titre,
    artiste: artiste,
    categorie: categorie,
    dureeMs: dureeMs,
    url: url,
    forme: forme,
    debutConseilleMs: debutConseilleMs,
    attribution: attribution,
    licence: licence,
    licenceUrl: licenceUrl,
    nombreReels: nombreReels,
    favori: f,
    actif: actif,
    importe: importe,
  );

  static Son depuis(Map<String, dynamic> j) => Son(
    id: j['id'] as String,
    titre: j['titre'] as String? ?? '',
    artiste: j['artiste'] as String? ?? '',
    categorie: j['categorie'] as String? ?? '',
    dureeMs: (j['duree_ms'] as num?)?.toInt() ?? 0,
    url: j['url'] as String? ?? '',
    forme: [for (final f in (j['forme'] as List? ?? const [])) (f as num).toInt()],
    debutConseilleMs: (j['debut_conseille_ms'] as num?)?.toInt() ?? 0,
    attribution: j['attribution'] as String? ?? '',
    licence: j['licence'] as String? ?? '',
    licenceUrl: j['licence_url'] as String?,
    nombreReels: (j['nombre_reels'] as num?)?.toInt() ?? 0,
    favori: j['favori'] == true,
    actif: j['actif'] != false,
    importe: j['importe'] == true,
  );
}

/// La musique choisie pour le reel en cours : le son, d ou il part, et les deux volumes (0 a 100).
class MusiqueChoisie {
  const MusiqueChoisie(this.son, {required this.debutMs, this.volume = 100, this.volumeOrigine = 100});

  final Son son;
  final int debutMs;
  final int volume;
  final int volumeOrigine;

  MusiqueChoisie copie({int? debutMs, int? volume, int? volumeOrigine}) =>
      MusiqueChoisie(son, debutMs: debutMs ?? this.debutMs, volume: volume ?? this.volume, volumeOrigine: volumeOrigine ?? this.volumeOrigine);

  Map<String, Object?> versServeur() => {'id': son.id, 'debut_ms': debutMs, 'volume': volume, 'volume_origine': volumeOrigine};
}

/// La musique du reel en cours, du choix (la page d un son, « Utiliser ce son ») au montage.
MusiqueChoisie? musiqueDuReel;

class Sons {
  Sons._();
  static final instance = Sons._();

  /// Les ambiances du catalogue, dans l ordre du serveur (gardees de la derniere page).
  List<String> categories = const ['afro', 'joyeux', 'energie', 'plage', 'calme', 'aventure'];

  /// Une page du catalogue : « Pour vous » (les plus utilises), une ambiance, mes favoris, ou une recherche.
  Future<({List<Son> sons, String? suite})> page({String? categorie, String? recherche, String? curseur}) async {
    final q = <String, String>{'categorie': ?categorie, if (recherche != null && recherche.trim().length >= 2) 'q': recherche.trim(), 'curseur': ?curseur};
    final r = await Api.instance.get(Uri(path: 'sons', queryParameters: q.isEmpty ? null : q).toString());
    final cats = (r.json['categories'] as List?)?.cast<String>();
    if (cats != null && cats.isNotEmpty) categories = cats;
    return (sons: [for (final s in (r.json['data'] as List? ?? const []).cast<Map>()) Son.depuis(s.cast<String, dynamic>())], suite: (r.json['meta'] as Map?)?['next_cursor'] as String?);
  }

  Future<Son> son(String id) async => Son.depuis(((await Api.instance.get('sons/$id')).json['data'] as Map).cast<String, dynamic>());

  /// Les reels qui utilisent ce son, les plus aimes d abord.
  Future<({List<Reel> reels, String? suite})> reels(String id, {String? curseur}) async {
    final r = await Api.instance.get(Uri(path: 'sons/$id/reels', queryParameters: curseur == null ? null : {'curseur': curseur}).toString());
    return (
      reels: Catalogue.instance.reelsDepuis([for (final x in (r.json['data'] as List? ?? const []).cast<Map>()) x.cast<String, dynamic>()]),
      suite: (r.json['meta'] as Map?)?['next_cursor'] as String?,
    );
  }

  /// Le garder (ou non) pour un prochain reel.
  /// Un son importe (le son d une video, un fichier du telephone) : il est aussitot a moi.
  Future<Son> importer(String chemin, {String titre = ''}) async {
    final r = await Api.instance.envoyerFichier('sons', 'fichier', File(chemin), champs: {if (titre.trim().isNotEmpty) 'titre': titre.trim()});
    return Son.depuis((r.json['data'] as Map).cast<String, dynamic>());
  }

  /// Un son importe qui pose probleme (les droits, son contenu).
  Future<void> signaler(String id) => Api.instance.post('sons/$id/signaler');

  Future<void> favori(String id, bool garder) => garder ? Api.instance.put('moi/sons/$id') : Api.instance.delete('moi/sons/$id');
}
