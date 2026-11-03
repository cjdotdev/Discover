// Une capture a publier : le fichier (photo ou video), et ce qu il dit de
// lui-meme : le telephone, la date, la position (l EXIF d une photo, la boite
// « moov » d une video, outils/metadonnees_video.dart).
// Une photo prise a l instant avec USW est completee par le telephone : son
// modele, l heure, la position actuelle (« USW y ajoute la position et le
// modele »). Tout est la : badge Capture verifiee ; sinon, on demande ce qui
// manque (E15) et la publication portera « Informations declarees ».
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:exif/exif.dart';
import 'package:geolocator/geolocator.dart';

import '../outils/appareil.dart';
import '../outils/langue.dart';
import '../outils/metadonnees_video.dart';
import 'catalogue.dart';
import 'modeles.dart';

/// Le lieu choisi pour une publication (E30) : un lieu de Discover, un point
/// pose sur la carte, ou un nom seul, sans position ; vide, la photo rejoint la
/// pile « Sans lieu ».
class ChoixLieu {
  const ChoixLieu({required this.nom, this.id, this.latitude, this.longitude, this.adresse, this.nomSeul = false});

  /// Pas de lieu : la pile « Sans lieu ».
  static const aucun = ChoixLieu(nom: '', nomSeul: true);

  final String nom;

  /// Un lieu de Discover (son identifiant), trouve par son nom ou tout pres du point.
  final String? id;

  /// Le point pose sur la carte, quand aucun lieu de Discover n y est.
  final double? latitude, longitude;

  /// La ville et le pays du point (Android) : de quoi creer le lieu.
  final Adresse? adresse;

  /// Un nom seul : les autres le lisent, sans savoir ou c est.
  final bool nomSeul;

  bool get vide => nomSeul && nom.isEmpty;

  String get affiche => vide ? 'Sans lieu' : nom;
}

class Capture {
  Capture({required this.chemin, this.video = false, this.modele, this.date, this.latitude, this.longitude, this.priseAvecUsw = false});

  final String chemin;
  final bool video;
  String? modele;
  DateTime? date;
  double? latitude;
  double? longitude;

  /// Le nom du lieu, donne par Android (quartier, ville, pays).
  Adresse? adresse;

  /// La couverture d une video (sa premiere image).
  String? vignette;

  /// Prise a l instant par l appareil photo, depuis USW.
  final bool priseAvecUsw;

  /// La date que le membre indique lui-meme quand le fichier ne la dit pas (E15) :
  /// choisie dans un calendrier qui s arrete a aujourd hui.
  DateTime? dateDeclaree;
  ChoixLieu? lieuChoisi;

  /// Le telephone, la date et le lieu viennent du fichier ou du telephone.
  bool get verifiee => modele != null && date != null && latitude != null && longitude != null;

  /// Le membre a indique lui-meme le telephone ou la date (E15) : « Informations declarees ».
  bool declaree = false;

  /// La duree d une video du lot (60 s au plus, deja coupee).
  int? duree;

  /// La capture en cours de publication (de Creer jusqu a Publier).
  static Capture? courante;

  /// Plusieurs fichiers choisis d un coup (10 au plus) : chacun devient une publication.
  static List<Capture> lot = [];

  /// Un lieu connu d USW s il est tout pres (2 km), sinon le nom donne par
  /// Android (quartier, ville), sinon le point GPS.
  String get lieu {
    final choisi = lieuChoisi;
    if (choisi != null) return choisi.affiche;
    final lat = latitude, lon = longitude;
    if (lat == null || lon == null) return 'Sans lieu';
    Lieu? proche;
    var mieux = 2.0;
    for (final l in Catalogue.instance.lieux.where((l) => l.situe)) {
      final d = Geolocator.distanceBetween(lat, lon, l.latitude, l.longitude) / 1000;
      if (d < mieux) {
        mieux = d;
        proche = l;
      }
    }
    String c(double v, String p, String m) => '${v.abs().toStringAsFixed(4).replaceAll('.', ',')}° ${v >= 0 ? p : m}';
    if (proche != null) return '${proche.nom}, ${proche.region.split(',').first}';
    final a = adresse;
    if (a != null && a.court.isNotEmpty) return a.court;
    return '${c(lat, 'N', 'S')}, ${c(lon, 'E', 'O')}';
  }

  /// « 12 août 2026 », comme sur la fiche de capture.
  String? get dateLisible {
    final d = date ?? dateDeclaree;
    return d == null ? null : jourLisible(d);
  }
}

/// « 12 août 2026 », dans la langue choisie.
String jourLisible(DateTime d) {
  final mois = switch (d.month) {
    1 => t('janvier'),
    2 => t('février'),
    3 => t('mars'),
    4 => t('avril'),
    5 => t('mai'),
    6 => t('juin'),
    7 => t('juillet'),
    8 => t('août'),
    9 => t('septembre'),
    10 => t('octobre'),
    11 => t('novembre'),
    _ => t('décembre'),
  };
  return t('{jour} {mois} {annee}', {'jour': d.day, 'mois': mois, 'annee': d.year});
}

// ------------------------------------------------------------ le telephone

String? _modeleDuTelephone;
String? _codeDuTelephone;

/// Le nom commercial de ce telephone (« Tecno Camon 50 Pro »), pas son code
/// (« TECNO CN5c ») : c est celui que les membres reconnaissent.
Future<String> modeleDuTelephone() async {
  if (_modeleDuTelephone != null) return _modeleDuTelephone!;
  try {
    final a = await DeviceInfoPlugin().androidInfo;
    _codeDuTelephone = a.model;
    final nom = a.name.trim().isNotEmpty && a.name.toLowerCase().contains(a.brand.toLowerCase()) ? a.name : '${a.brand} ${a.model}';
    _modeleDuTelephone = _joli(nom);
  } catch (_) {
    _modeleDuTelephone = 'Ce téléphone';
  }
  return _modeleDuTelephone!;
}

/// Le telephone lu dans un fichier : le nom commercial de ce telephone s il en vient
/// (plutot que son code), sinon la marque et le modele du fichier.
Future<String> _nomDuTelephone(String? marque, String modele) async {
  final telephone = await modeleDuTelephone();
  if (modele == _codeDuTelephone) return telephone;
  return _joli(marque != null && marque.isNotEmpty && !modele.toLowerCase().startsWith(marque.toLowerCase()) ? '$marque $modele' : modele);
}

// « TECNO CAMON 50 Pro » -> « Tecno Camon 50 Pro » : les mots tout en
// majuscules prennent une capitale seulement ; les sigles courts restent.
String _joli(String nom) => nom.split(RegExp(r'\s+')).map((m) => m.length > 3 && m == m.toUpperCase() && RegExp(r'[A-Z]').hasMatch(m) ? m[0] + m.substring(1).toLowerCase() : m).join(' ');

/// Pourquoi la position manque, pour le dire clairement (E15).
enum SansPosition { coupee, refusee, introuvable }

/// La raison de la derniere position manquee ; nulle si elle a ete trouvee.
SansPosition? positionManquee;

// La fenetre « Activer la localisation » ne revient pas si on l a refusee.
bool _activationRefusee = false;

/// La fenetre du systeme « Activer la localisation », a chaque fois : coupee,
/// ou allumee sans la precision qu il faut. Puis la permission de USW. Vrai si
/// tout est pret.
Future<bool> demanderLocalisation() async {
  try {
    if (!await Appareil.activerPosition()) {
      positionManquee = SansPosition.coupee;
      return false;
    }
    _activationRefusee = false;
    var droit = await Geolocator.checkPermission();
    if (droit == LocationPermission.denied) droit = await Geolocator.requestPermission();
    if (droit == LocationPermission.deniedForever) {
      // Refusee pour de bon : Android n affiche plus sa fenetre, seuls ses reglages le peuvent.
      positionManquee = SansPosition.refusee;
      await Geolocator.openAppSettings();
      return false;
    }
    if (droit == LocationPermission.denied) {
      positionManquee = SansPosition.refusee;
      return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Avant d ouvrir l appareil photo : allumer la localisation et demander la
/// permission, s il le faut ; la recherche viendra ensuite, sans fenetre.
Future<void> preparerPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (_activationRefusee || !await Appareil.activerPosition()) {
        _activationRefusee = true;
        positionManquee = SansPosition.coupee;
        return;
      }
    }
    if (await Geolocator.checkPermission() == LocationPermission.denied) await Geolocator.requestPermission();
  } catch (_) {}
}

/// La position actuelle. Si la localisation du telephone est coupee, Android
/// propose de l allumer (une fois) ; si USW n a pas la permission, il la demande.
Future<Position?> positionActuelle({bool demander = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      final allumee = demander && !_activationRefusee && await Appareil.activerPosition();
      if (!allumee) {
        if (demander) _activationRefusee = true;
        positionManquee = SansPosition.coupee;
        return null;
      }
    }
    var droit = await Geolocator.checkPermission();
    if (droit == LocationPermission.denied && demander) droit = await Geolocator.requestPermission();
    if (droit == LocationPermission.denied || droit == LocationPermission.deniedForever) {
      positionManquee = SansPosition.refusee;
      return null;
    }
    // Une position de moins de 2 minutes suffit : elle est la tout de suite.
    final derniere = await Geolocator.getLastKnownPosition();
    if (derniere != null && DateTime.now().difference(derniere.timestamp).inMinutes < 2) {
      positionManquee = null;
      return derniere;
    }
    // Le telephone cherche vraiment sa position (GPS, Wi-Fi), meme si aucune autre
    // application ne l a demandee depuis que la localisation est allumee.
    final f = await Appareil.position();
    if (f != null) {
      positionManquee = null;
      return Position(
        latitude: f.latitude,
        longitude: f.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
    );
    positionManquee = null;
    return p;
  } catch (_) {
    final p = await Geolocator.getLastKnownPosition().catchError((_) => null);
    positionManquee = p == null ? SansPosition.introuvable : null;
    return p;
  }
}

// ------------------------------------------------------------ le fichier

/// Lit une capture. `priseAvecUsw` : prise a l instant, on complete avec le
/// telephone ce que le fichier ne dit pas. `lireDans` : le fichier d origine,
/// quand `chemin` en est une copie coupee (une video de plus de 60 s, qui y
/// perd sa date et sa position).
Future<Capture> lireCapture(String chemin, {bool video = false, bool priseAvecUsw = false, Future<Position?>? position, DateTime? date, String? lireDans}) async {
  final capture = Capture(chemin: chemin, video: video, priseAvecUsw: priseAvecUsw);
  final source = lireDans ?? chemin;
  if (video) {
    final m = await lireMetadonneesVideo(source);
    final modele = m.modele;
    if (modele != null) capture.modele = await _nomDuTelephone(m.marque, modele);
    capture.date = datePlausible(m.date);
    if (m.latitude != null && m.longitude != null) {
      capture
        ..latitude = m.latitude
        ..longitude = m.longitude;
    }
  } else {
    try {
      final tags = await readExifFromBytes(await File(source).readAsBytes());
      final marque = tags['Image Make']?.printable.trim();
      final modele = tags['Image Model']?.printable.trim();
      if (modele != null && modele.isNotEmpty) capture.modele = await _nomDuTelephone(marque, modele);
      capture.date = datePlausible(_date(tags['EXIF DateTimeOriginal']?.printable ?? tags['Image DateTime']?.printable));
      final lat = _degres(tags['GPS GPSLatitude'], tags['GPS GPSLatitudeRef']?.printable);
      final lon = _degres(tags['GPS GPSLongitude'], tags['GPS GPSLongitudeRef']?.printable);
      if (lat != null && lon != null && !(lat == 0 && lon == 0)) {
        capture
          ..latitude = lat
          ..longitude = lon;
      }
    } catch (_) {
      // Un fichier sans EXIF lisible : tout sera a declarer.
    }
  }
  if (priseAvecUsw) {
    capture.modele ??= await modeleDuTelephone();
    capture.date ??= date ?? DateTime.now();
    if (capture.latitude == null) {
      // La position cherchee pendant que l appareil photo etait ouvert.
      final p = await (position ?? positionActuelle());
      if (p != null) {
        capture
          ..latitude = p.latitude
          ..longitude = p.longitude;
      }
    }
  }
  // Le nom du lieu, des que la position est connue.
  final lat = capture.latitude, lon = capture.longitude;
  if (lat != null && lon != null) capture.adresse = await Appareil.adresse(lat, lon);
  return capture;
}

/// Une date de prise dans le futur (l horloge du telephone etait mal reglee) ne vaut rien :
/// on la demande au membre. Un jour de marge pour les fuseaux horaires.
DateTime? datePlausible(DateTime? d) => d == null || d.isAfter(DateTime.now().add(const Duration(days: 1))) ? null : d;

// « 2026:08:12 17:40:03 »
DateTime? _date(String? texte) {
  final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2})').firstMatch(texte?.trim() ?? '');
  if (m == null) return null;
  final valeurs = [for (var i = 1; i <= 5; i++) int.parse(m.group(i)!)];
  if (valeurs[0] < 1990) return null;
  return DateTime(valeurs[0], valeurs[1], valeurs[2], valeurs[3], valeurs[4]);
}

// Degres, minutes, secondes (trois rapports) -> degres decimaux, signe par N/S, E/O.
double? _degres(IfdTag? tag, String? reference) {
  if (tag == null) return null;
  final v = tag.values.toList();
  if (v.length < 3) return null;
  double n(Object? x) => x is Ratio ? x.toDouble() : (x is num ? x.toDouble() : 0);
  final d = n(v[0]) + n(v[1]) / 60 + n(v[2]) / 3600;
  // Un GPS sans signal ecrit 0/0 : pas de position plutot qu une valeur impossible.
  if (!d.isFinite || d > 180) return null;
  return (reference == 'S' || reference == 'W') ? -d : d;
}
