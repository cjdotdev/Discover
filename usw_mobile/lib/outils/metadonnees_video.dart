// Ce qu une video (MP4, MOV, 3GP) dit d elle-meme, lu dans sa boite « moov »
// sans lire le reste du fichier : la date de la prise, la position et le
// telephone. Android l ecrit dans « mvhd » (la date), « udta/©xyz » (la
// position) et « meta/keys » (com.android.manufacturer, com.android.model) ;
// l iPhone dans « meta/keys » (com.apple.quicktime.*). Ce que le fichier ne
// dit pas reste nul : il sera a declarer, comme pour une photo.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class MetadonneesVideo {
  const MetadonneesVideo({this.marque, this.modele, this.date, this.latitude, this.longitude});

  static const vide = MetadonneesVideo();

  final String? marque, modele;
  final DateTime? date;
  final double? latitude, longitude;
}

/// Une boite « moov » plus grande n est pas lue (elle fait d ordinaire quelques centaines de Ko).
const _plafondMoov = 32 * 1024 * 1024;

Future<MetadonneesVideo> lireMetadonneesVideo(String chemin) async {
  RandomAccessFile? f;
  try {
    f = await File(chemin).open();
    final longueur = await f.length();
    var position = 0;
    // Les boites du premier niveau : ftyp, mdat (la video, enorme), moov (avant ou apres).
    while (position + 8 <= longueur) {
      await f.setPosition(position);
      final entete = await f.read(16);
      if (entete.length < 8) break;
      final d = ByteData.sublistView(entete);
      var taille = d.getUint32(0);
      final type = String.fromCharCodes(entete.sublist(4, 8));
      var debut = 8;
      if (taille == 1) {
        if (entete.length < 16) break;
        taille = d.getUint64(8);
        debut = 16;
      } else if (taille == 0) {
        taille = longueur - position;
      }
      if (taille < debut) break;
      if (type == 'moov') {
        if (taille > _plafondMoov) break;
        await f.setPosition(position + debut);
        return lireMoov(await f.read(taille - debut));
      }
      position += taille;
    }
  } catch (_) {
    // Un fichier illisible : rien n est dit.
  } finally {
    await f?.close();
  }
  return MetadonneesVideo.vide;
}

/// Le contenu de la boite « moov » (sans son entete). Public pour les tests.
MetadonneesVideo lireMoov(Uint8List moov) {
  final valeurs = <String, String>{};
  DateTime? dateMvhd;

  void parcourir(Uint8List b, int de, int a) {
    for (final (type, debut, fin) in _boites(b, de, a)) {
      switch (type) {
        case 'mvhd':
          dateMvhd ??= _dateMvhd(b, debut, fin);
        case 'udta':
          parcourir(b, debut, fin);
        case 'meta':
          // QuickTime : une boite simple ; ISO : 4 octets de version et de drapeaux d abord.
          final iso = fin - debut >= 12 && _u32(b, debut) == 0 && String.fromCharCodes(b.sublist(debut + 8, debut + 12)) == 'hdlr';
          _lireMeta(b, iso ? debut + 4 : debut, fin, valeurs);
        case '©xyz' || '©mak' || '©mod' || '©day':
          final t = _texteUdta(b, debut, fin);
          if (t != null) valeurs.putIfAbsent(type, () => t);
      }
    }
  }

  parcourir(moov, 0, moov.length);

  String? une(List<String> cles) {
    for (final c in cles) {
      final v = valeurs[c]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  final lieu = _iso6709(une(['com.apple.quicktime.location.ISO6709', '©xyz']));
  // La date de l iPhone a l heure locale d abord ; sinon celle de « mvhd » (en UTC).
  final date = _dateTexte(une(['com.apple.quicktime.creationdate', '©day'])) ?? dateMvhd;
  return MetadonneesVideo(
    marque: une(['com.android.manufacturer', 'com.apple.quicktime.make', '©mak']),
    modele: une(['com.android.model', 'com.apple.quicktime.model', '©mod']),
    date: date != null && date.year >= 1990 && date.isBefore(DateTime.now().add(const Duration(days: 2))) ? date : null,
    latitude: lieu?.$1,
    longitude: lieu?.$2,
  );
}

/// Les boites entre deux positions : (type, debut du contenu, fin).
Iterable<(String, int, int)> _boites(Uint8List b, int de, int a) sync* {
  var p = de;
  while (p + 8 <= a) {
    var taille = _u32(b, p);
    var entete = 8;
    if (taille == 1) {
      if (p + 16 > a) return;
      taille = ByteData.sublistView(b).getUint64(p + 8);
      entete = 16;
    } else if (taille == 0) {
      taille = a - p;
    }
    if (taille < entete || p + taille > a) return;
    yield (latin1.decode(b.sublist(p + 4, p + 8)), p + entete, p + taille);
    p += taille;
  }
}

int _u32(Uint8List b, int p) => ByteData.sublistView(b).getUint32(p);

DateTime? _dateMvhd(Uint8List b, int debut, int fin) {
  if (fin - debut < 12) return null;
  final version = b[debut];
  final secondes = version == 1 ? ByteData.sublistView(b).getUint64(debut + 4) : _u32(b, debut + 4);
  if (secondes == 0) return null;
  return DateTime.utc(1904).add(Duration(seconds: secondes)).toLocal();
}

/// « meta » : « keys » donne les noms (com.android.model...), « ilst » les valeurs, par rang.
void _lireMeta(Uint8List b, int de, int a, Map<String, String> valeurs) {
  final cles = <String>[];
  for (final (type, debut, fin) in _boites(b, de, a)) {
    if (type != 'keys' || fin - debut < 8) continue;
    final nombre = _u32(b, debut + 4);
    var p = debut + 8;
    for (var i = 0; i < nombre && p + 8 <= fin; i++) {
      final taille = _u32(b, p);
      if (taille < 8 || p + taille > fin) break;
      cles.add(utf8.decode(b.sublist(p + 8, p + taille), allowMalformed: true));
      p += taille;
    }
  }
  for (final (type, debut, fin) in _boites(b, de, a)) {
    if (type != 'ilst') continue;
    for (final (_, d, f) in _boites(b, debut, fin)) {
      // Le type de l element est le rang de sa cle (a partir de 1), en 4 octets.
      final rang = _u32(b, d - 4);
      if (rang < 1 || rang > cles.length) continue;
      for (final (t, dd, ff) in _boites(b, d, f)) {
        // « data » : 4 octets de type (1 = UTF-8), 4 de langue, puis la valeur.
        if (t == 'data' && ff - dd > 8 && _u32(b, dd) & 0xFFFFFF == 1) {
          valeurs.putIfAbsent(cles[rang - 1], () => utf8.decode(b.sublist(dd + 8, ff), allowMalformed: true));
        }
      }
    }
  }
}

/// Une chaine de « udta » (©xyz, ©mod...) : 2 octets de longueur, 2 de langue, puis le texte.
String? _texteUdta(Uint8List b, int debut, int fin) {
  if (fin - debut < 4) return null;
  final n = ByteData.sublistView(b).getUint16(debut);
  if (n == 0 || debut + 4 + n > fin) return null;
  return utf8.decode(b.sublist(debut + 4, debut + 4 + n), allowMalformed: true);
}

/// « +06.3654+002.4183/ » ou « +48.8584+002.2945+035.000/ ».
(double, double)? _iso6709(String? texte) {
  final m = RegExp(r'^([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)').firstMatch(texte?.trim() ?? '');
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!), lon = double.tryParse(m.group(2)!);
  if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180 || (lat == 0 && lon == 0)) return null;
  return (lat, lon);
}

/// « 2023-10-15T12:34:56+0100 » (iPhone) : l heure du lieu de la prise, gardee telle quelle.
DateTime? _dateTexte(String? texte) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(texte?.trim() ?? '');
  if (m == null) return null;
  int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
}
