// Telecharger : la photo ou la video part dans la galerie du telephone, dans
// un album « Discover ». Une publication du serveur : sa plus grande taille
// (ou l original, si le serveur le garde), par GET contenus/{id}/original ;
// une photo de demonstration : lue dans les assets ; un fichier du telephone :
// tel quel.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'connexion.dart';

/// L extension d une image d apres ses premiers octets : WebP, PNG, ou JPEG.
String _extension(List<int> o) {
  bool debut(List<int> signature, [int depuis = 0]) => o.length >= depuis + signature.length && [for (var i = 0; i < signature.length; i++) o[depuis + i] == signature[i]].every((v) => v);
  if (debut('RIFF'.codeUnits) && debut('WEBP'.codeUnits, 8)) return 'webp';
  if (debut(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  return 'jpg';
}

/// Ce qu a donne un telechargement : dans la galerie, galerie refusee, ou echec (le reseau, le fichier).
enum Telechargement { ok, galerieRefusee, echec }

/// Vrai si c est dans la galerie ; faux si l acces est refuse ou si
/// l enregistrement a echoue (pas de reseau compris).
Future<bool> enregistrerDansGalerie(String photo, {String? contenu, bool video = false, bool grandeTaille = true, String? taille}) async =>
    await telechargerDansGalerie(photo, contenu: contenu, video: video, grandeTaille: grandeTaille, taille: taille) == Telechargement.ok;

final _client = HttpClient()
  ..connectionTimeout = const Duration(seconds: 15)
  ..connectionFactory = connecterIPv4DAbord;

/// Les octets d une adresse, et l avance (de 0 a 1) a mesure qu ils arrivent. Hors du dossier
/// des images : une 4K ou une video telechargee une fois n a pas a y prendre de la place.
Future<Uint8List> _octetsAvecAvance(String url, void Function(double)? avance) async {
  final requete = await _client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 20));
  final reponse = await requete.close().timeout(const Duration(seconds: 30));
  if (reponse.statusCode != 200) {
    await reponse.drain<void>();
    throw HttpException('telechargement ${reponse.statusCode}', uri: Uri.parse(url));
  }
  final total = reponse.contentLength;
  final b = BytesBuilder(copy: false);
  // Un morceau qui n arrive plus en 30 s : la connexion est perdue.
  await for (final morceau in reponse.timeout(const Duration(seconds: 30))) {
    b.add(morceau);
    if (total > 0) avance?.call(b.length / total);
  }
  return b.takeBytes();
}

/// Comme [enregistrerDansGalerie], en disant pourquoi cela n a pas abouti. [taille] : « 1080 »,
/// « 2160 », « 3840 », « video » ou « video-1080 » ; nulle, la plus grande.
/// [avance] suit le telechargement (de 0 a 1), pour la notification et Mes envois.
Future<Telechargement> telechargerDansGalerie(String photo, {String? contenu, bool video = false, bool grandeTaille = true, String? taille, void Function(double)? avance}) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) return Telechargement.galerieRefusee;
  } catch (_) {
    return Telechargement.galerieRefusee;
  }
  try {
    final nom = 'discover-${contenu ?? DateTime.now().millisecondsSinceEpoch}';
    var source = photo;
    if (contenu != null && grandeTaille) {
      final r = await Api.instance.get('contenus/${Uri.encodeComponent(contenu)}/original${taille == null ? '' : '?taille=$taille'}');
      source = (r.json['url'] as String?) ?? photo;
    }
    if (source.startsWith('http')) {
      final octets = await _octetsAvecAvance(source, avance);
      if (video) {
        // Gal enregistre une video depuis un fichier : elle passe par le cache.
        final f = File('${(await getTemporaryDirectory()).path}/$nom.mp4');
        await f.writeAsBytes(octets, flush: true);
        await Gal.putVideo(f.path, album: 'Discover');
        await f.delete().catchError((_) => f);
      } else {
        // Par un fichier a la bonne extension : depuis des octets, Gal devine le format et ne
        // connait pas le WebP (nos photos) ; Android refusait alors l image (GalException).
        final f = File('${(await getTemporaryDirectory()).path}/$nom.${_extension(octets)}');
        await f.writeAsBytes(octets, flush: true);
        try {
          await Gal.putImage(f.path, album: 'Discover');
        } finally {
          await f.delete().catchError((_) => f);
        }
      }
    } else if (source.startsWith('/')) {
      video ? await Gal.putVideo(source, album: 'Discover') : await Gal.putImage(source, album: 'Discover');
    } else {
      return Telechargement.echec;
    }
    return Telechargement.ok;
  } catch (e) {
    // Dans le journal du telephone (adb logcat) : sans cela, un echec ne laissait aucune trace.
    debugPrint('Téléchargement impossible ($photo) : $e');
    return Telechargement.echec;
  }
}
