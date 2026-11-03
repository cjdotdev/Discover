// Les photos du serveur (Cloudflare R2), gardees sur le telephone : une photo
// vue une fois s affiche ensuite tout de suite, meme hors ligne, et ne se
// telecharge plus. C est le telephone qui garde ce qu il a deja vu, pas le
// serveur qui le renvoie. Le dossier reste borne (200 Mo, les plus anciennes
// partent d abord).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import 'connexion.dart';

class ImagesReseau {
  ImagesReseau._();

  static const _plafond = 200 * 1024 * 1024;
  static Directory? _dossier;
  static final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..connectionFactory = connecterIPv4DAbord;

  /// Les telechargements en cours : deux vignettes de la meme photo n en font qu un.
  static final _enCours = <String, Future<Uint8List>>{};

  /// Les images que le serveur n avait pas (404, une publication supprimee, ou pas encore prete
  /// juste apres la publication) : pas redemandees a chaque affichage de la liste, mais de
  /// nouveau quelques secondes plus tard (Photo les redemande).
  static final _absentes = <String, DateTime>{};
  static const _absenteDurant = Duration(seconds: 3);

  static final _sousTest = Platform.environment.containsKey('FLUTTER_TEST');

  /// Les photos deja sur le telephone (lues du disque ou telechargees) : la vitrine de la
  /// bienvenue et de l entree montre une image du paquet a la place des autres, pas une case vide.
  static final pretes = PhotosPretes._();

  static Future<Directory> _dossierImages() async {
    final d = _dossier;
    if (d != null) return d;
    final racine = await getApplicationCacheDirectory();
    final dossier = Directory('${racine.path}/images');
    await dossier.create(recursive: true);
    return _dossier = dossier;
  }

  /// Un nom de fichier stable pour une adresse (FNV-1a, 64 bits).
  static String _nom(String url) {
    var h = 0xcbf29ce484222325;
    for (final c in url.codeUnits) {
      h ^= c;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  /// Les octets de l image : du disque si elle y est, sinon du reseau (puis gardes).
  static Future<Uint8List> octets(String url) {
    final absente = _absentes[url];
    if (absente != null && DateTime.now().difference(absente) < _absenteDurant) return Future.error(HttpException('image 404', uri: Uri.parse(url)));
    // (Sous les tests, pas de reseau ni de minuterie qui survive au test.)
    // Le bloc ne rend rien : rendre _enCours.remove(url), c est rendre cette tache elle-meme,
    // que whenComplete attendrait sans fin (toutes les photos restaient noires).
    return _enCours[url] ??= (_sousTest ? _charger(url) : _avecEssais(url)).whenComplete(() {
      _enCours.remove(url);
    });
  }

  /// Le reseau mobile coupe parfois une connexion en route : l image se redemande (3 essais),
  /// et un essai qui cale abandonne. Sans cela, une coupure laissait la case vide (ou noire)
  /// jusqu au prochain lancement. Une image absente du serveur (404) ne se redemande pas.
  static Future<Uint8List> _avecEssais(String url) async {
    for (var essai = 1; ; essai++) {
      try {
        return await _charger(url).timeout(const Duration(seconds: 25));
      } on HttpException catch (e) {
        // Flutter tait les echecs d image (une image de remplacement est prevue) : ils
        // vont dans le journal du telephone, sinon une image absente ne laisse aucune trace.
        debugPrint('Image impossible ($url), essai $essai : $e');
        if (e.message.startsWith('image 4')) {
          _absentes[url] = DateTime.now();
          rethrow;
        }
        if (essai >= 3) rethrow;
      } on Exception catch (e) {
        debugPrint('Image impossible ($url), essai $essai : $e');
        if (essai >= 3) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 700 * essai));
    }
  }

  static Future<Uint8List> _charger(String url) async {
    final f = File('${(await _dossierImages()).path}/${_nom(url)}');
    if (await f.exists()) {
      // Toucher le fichier : le menage garde les photos regardees recemment.
      unawaited(f.setLastModified(DateTime.now()).catchError((_) {}));
      final lus = await f.readAsBytes();
      pretes._ajouter(url);
      return lus;
    }
    final requete = await _client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
    final reponse = await requete.close().timeout(const Duration(seconds: 30));
    if (reponse.statusCode != 200) {
      await reponse.drain<void>();
      throw HttpException('image ${reponse.statusCode}', uri: Uri.parse(url));
    }
    final b = BytesBuilder(copy: false);
    await for (final morceau in reponse) {
      b.add(morceau);
    }
    final donnees = b.takeBytes();
    // Ecrit a cote puis renomme : une coupure ne laisse pas d image a moitie.
    final temp = File('${f.path}.part');
    await temp.writeAsBytes(donnees, flush: true);
    await temp.rename(f.path);
    pretes._ajouter(url);
    return donnees;
  }

  /// Au demarrage : au-dela de 200 Mo, les photos les moins recemment vues partent.
  static Future<void> menage() async {
    try {
      final d = await _dossierImages();
      final fichiers = <(File, FileStat)>[];
      var total = 0;
      await for (final e in d.list()) {
        if (e is File) {
          final s = await e.stat();
          fichiers.add((e, s));
          total += s.size;
        }
      }
      if (total <= _plafond) return;
      fichiers.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (f, s) in fichiers) {
        if (total <= _plafond * 0.8) break;
        await f.delete().catchError((_) => f);
        total -= s.size;
      }
    } catch (_) {}
  }

  /// La place prise par les photos gardees, en octets (Reglages, Stockage).
  static Future<int> taille() async {
    var total = 0;
    try {
      await for (final e in (await _dossierImages()).list()) {
        if (e is File) total += await e.length();
      }
    } catch (_) {}
    return total;
  }

  /// Vider les photos gardees (Reglages, Stockage) : elles se retelechargeront.
  static Future<void> vider() async {
    try {
      final d = await _dossierImages();
      await d.delete(recursive: true);
      await d.create(recursive: true);
    } catch (_) {}
    PaintingBinding.instance.imageCache.clear();
  }
}

/// Une image du serveur, passee par le dossier du telephone (ImagesReseau).
@immutable
class ImageReseau extends ImageProvider<ImageReseau> {
  const ImageReseau(this.url);

  final String url;

  @override
  Future<ImageReseau> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(ImageReseau key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _decoder(decode), scale: 1, debugLabel: url, informationCollector: () => [DiagnosticsProperty<String>('Adresse', url)]);

  Future<ui.Codec> _decoder(ImageDecoderCallback decode) async {
    final octets = await ImagesReseau.octets(url);
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(octets));
    } catch (e) {
      debugPrint('Image illisible ($url, ${octets.length} octets) : $e');
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) => other is ImageReseau && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Les adresses des photos arrivees sur le telephone. Previent ceux qui l ecoutent, un peu
/// apres coup : dix photos arrivees ensemble ne redessinent qu une fois.
class PhotosPretes extends ChangeNotifier {
  PhotosPretes._();

  final _urls = <String>{};
  Timer? _prevenir;

  bool contient(String url) => _urls.contains(url);

  void _ajouter(String url) {
    if (!_urls.add(url)) return;
    if (ImagesReseau._sousTest) return notifyListeners();
    _prevenir ??= Timer(const Duration(milliseconds: 150), () {
      _prevenir = null;
      notifyListeners();
    });
  }
}
