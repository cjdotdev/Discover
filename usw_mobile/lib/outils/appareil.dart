// L appareil photo du telephone, en grand, avec tous ses modes (Portrait,
// Nuit, AI CAM…), et non l ecran reduit qu Android donne d ordinaire aux
// applications. Au retour, USW retrouve ce qui vient d etre pris
// (android/…/Appareil.kt). Aussi : couper une video, en tirer une image,
// allumer la localisation.
import 'package:flutter/services.dart';

/// Une photo ou une video que l appareil photo vient d enregistrer, copiee
/// dans le cache d USW avec ses informations d origine.
class PriseFaite {
  const PriseFaite(this.chemin, {required this.video, required this.date});

  final String chemin;
  final bool video;
  final DateTime date;
}

/// Le nom d un lieu, donne par Android a partir d une position.
class Adresse {
  const Adresse({required this.quartier, required this.ville, required this.region, required this.pays, this.code = ''});

  final String quartier;
  final String ville;
  final String region;
  final String pays;

  /// Le code du pays (BJ, TG…) : de quoi creer un lieu que Discover ne connait pas.
  final String code;

  /// « Akpakpa, Cotonou », ou la region si la ville manque.
  String get court => [quartier, ville.isNotEmpty ? ville : region].where((s) => s.isNotEmpty).toSet().join(', ');
}

class Appareil {
  static const _canal = MethodChannel('bj.usw/appareil');

  static List<PriseFaite> _liste(Object? brut) => [
    for (final m in (brut as List?) ?? const [])
      if (m is Map) PriseFaite(m['chemin'] as String, video: m['video'] == true, date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt())),
  ];

  /// Ouvre l appareil photo (en mode video si `video`) et rend ce qui a ete
  /// pris, du plus recent au plus ancien ; vide si rien n a ete pris.
  static Future<List<PriseFaite>> ouvrir({required bool video}) async => _liste(await _canal.invokeMethod<Object?>('ouvrir', {'video': video}));

  /// Discover peut revenir tout seul apres la prise (autorise a s afficher par-dessus).
  static Future<bool> retourAuto() async {
    try {
      return await _canal.invokeMethod<bool>('retourAuto') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// La page d Android ou la personne autorise Discover a s afficher par-dessus.
  static Future<void> demanderRetourAuto() async {
    try {
      await _canal.invokeMethod<void>('demanderRetourAuto');
    } catch (_) {}
  }

  /// Ce qui a ete pris depuis `date` (USW avait ete ferme par Android).
  static Future<List<PriseFaite>> depuis(DateTime date) async {
    try {
      return _liste(await _canal.invokeMethod<Object?>('depuis', {'depuis': date.millisecondsSinceEpoch}));
    } on Exception {
      return const [];
    }
  }

  /// USW peut lire la galerie (sinon il ne retrouve pas la prise).
  static Future<bool> acces() async {
    try {
      return await _canal.invokeMethod<bool>('acces') ?? false;
    } on Exception {
      return false;
    }
  }

  /// La video de `debut` a `duree` (la fin), sans la reencoder ; sans `son`, muette.
  static Future<String?> couper(String chemin, Duration duree, {Duration debut = Duration.zero, bool son = true}) async {
    try {
      return await _canal.invokeMethod<String>('couper', {'chemin': chemin, 'debutMs': debut.inMilliseconds, 'finMs': duree.inMilliseconds, 'son': son});
    } on Exception {
      return null;
    }
  }

  /// La notification des envois en cours : elle garde Discover en vie quand on le quitte.
  static Future<void> envoisEnFond({required String titre, required String texte, required int avance}) async {
    try {
      await _canal.invokeMethod<void>('envoisEnFond', {'titre': titre, 'texte': texte, 'avance': avance});
    } on Exception {
      // Rien : les envois continuent tant que Discover est ouvert.
    }
  }

  static Future<void> envoisFinis() async {
    try {
      await _canal.invokeMethod<void>('envoisFinis');
    } on Exception {
      // Rien a arreter.
    }
  }

  /// Le fichier a envoyer, allege sur le telephone (une photo en JPEG de 4 096 px avec ses
  /// informations, une video en 1080p) ; l original s il est deja leger ou en cas d echec.
  static Future<String> optimiser(String chemin, {required bool video}) async {
    try {
      return await _canal.invokeMethod<String>('optimiser', {'chemin': chemin, 'video': video}) ?? chemin;
    } on Exception {
      return chemin;
    }
  }

  /// Le son d une video (sa piste audio seule, dans un .m4a) ; nul si elle n en a pas.
  static Future<String?> extraireSon(String chemin) async {
    try {
      return await _canal.invokeMethod<String>('extraireSon', {'chemin': chemin});
    } on Exception {
      return null;
    }
  }

  /// Un fichier audio choisi dans le telephone (le selecteur d Android), copie dans l application.
  static Future<String?> choisirAudio() async {
    try {
      return await _canal.invokeMethod<String>('choisirAudio');
    } on Exception {
      return null;
    }
  }

  /// La premiere image d une video, en JPEG : sa couverture.
  static Future<String?> vignette(String chemin) async {
    try {
      return await _canal.invokeMethod<String>('vignette', {'chemin': chemin});
    } on Exception {
      return null;
    }
  }

  /// Le nom du lieu d une position (Internet requis) ; nul si introuvable.
  static Future<Adresse?> adresse(double latitude, double longitude) async {
    try {
      final m = await _canal.invokeMapMethod<String, String>('adresse', {'lat': latitude, 'lon': longitude}).timeout(const Duration(seconds: 5));
      if (m == null) return null;
      return Adresse(quartier: m['quartier'] ?? '', ville: m['ville'] ?? '', region: m['region'] ?? '', pays: m['pays'] ?? '', code: m['code'] ?? '');
    } catch (_) {
      return null;
    }
  }

  /// La localisation est coupee : Android propose de l allumer, en un toucher.
  /// Une position fraiche, cherchee par le telephone (GPS, Wi-Fi) ; null sans permission ou sans signal.
  static Future<({double latitude, double longitude})?> position() async {
    try {
      final m = await _canal.invokeMapMethod<String, double>('position').timeout(const Duration(seconds: 18));
      if (m == null || m['lat'] == null || m['lon'] == null) return null;
      return (latitude: m['lat']!, longitude: m['lon']!);
    } catch (_) {
      return null;
    }
  }

  /// L apercu a envoyer d abord : la photo redressee, en WebP de `cote` px au plus.
  static Future<String?> apercu(String chemin, {int cote = 2160}) async {
    try {
      return await _canal.invokeMethod<String>('apercu', {'chemin': chemin, 'cote': cote}).timeout(const Duration(seconds: 30));
    } catch (_) {
      return null;
    }
  }

  /// La memoire du telephone (memoireMo), s il est petit (faible) et la plus grande texture (textureMax).
  static Future<Map<String, Object?>?> capacites() async {
    try {
      return await _canal.invokeMapMethod<String, Object?>('capacites').timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// L empreinte SHA-256 d un fichier, en hexadecimal.
  static Future<String?> empreinte(String chemin) async {
    try {
      return await _canal.invokeMethod<String>('empreinte', {'chemin': chemin}).timeout(const Duration(minutes: 2));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> activerPosition() async {
    try {
      return await _canal.invokeMethod<bool>('activerPosition') ?? false;
    } on Exception {
      return false;
    }
  }
}
