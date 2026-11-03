// Les videos gardees sur le telephone, comme Instagram ou TikTok : une video deja vue (ou
// prechargee, les reels qui suivent) se relance aussitot depuis le telephone, sans attendre le
// reseau ni montrer du noir. La premiere fois, elle se lit en continu depuis le serveur pendant
// qu elle se garde a cote. 300 Mo au plus : les plus anciennes partent d abord.
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class Videos {
  Videos._();
  static final instance = Videos._();

  static const _plafond = 300 * 1024 * 1024;

  /// Deux telechargements a la fois : les videos a l ecran gardent le reseau.
  static const _enMemeTemps = 2;

  Directory? _dossier;
  final _enCours = <String, Future<File?>>{};
  final _file = <String>[];
  int _actifs = 0;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

  Future<Directory> _ici() async {
    final d = _dossier ??= Directory('${(await getApplicationCacheDirectory()).path}/videos');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  // Le nom du fichier : tire de l adresse (deux variantes d une meme video ne se melangent pas),
  // le meme d une ouverture a l autre (FNV-1a sur 32 bits).
  String _nom(String url) {
    var h = 0x811c9dc5;
    for (final c in url.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return '${h.toRadixString(16)}_${url.length}.mp4';
  }

  /// Le fichier deja garde de cette video, nul sinon.
  Future<File?> gardee(String url) async {
    final f = File('${(await _ici()).path}/${_nom(url)}');
    if (!f.existsSync()) return null;
    // Vue a l instant : elle passe en dernier dans le menage.
    unawaited(f.setLastModified(DateTime.now()).catchError((_) {}));
    return f;
  }

  /// Le lecteur d une video : depuis le telephone si elle y est, sinon en continu (et gardee pour
  /// la prochaine fois). Une adresse locale (un reel publie d ici) se lit telle quelle. Un de ses
  /// [replis] (la meme en plus leger, vue dans une grille) deja sur le telephone part aussitot,
  /// pendant que l autre se garde pour la prochaine fois. Deja en train d arriver (prechargee) :
  /// on l attend un peu plutot que de la tirer deux fois du reseau.
  Future<VideoPlayerController> lecteur(String source, {List<String> replis = const [], VideoPlayerOptions? options}) async {
    if (!source.startsWith('http')) return VideoPlayerController.file(File(source), videoPlayerOptions: options);
    final f = await gardee(source);
    if (f != null) return VideoPlayerController.file(f, videoPlayerOptions: options);
    for (final repli in replis) {
      if (repli == source) continue;
      if (await gardee(repli) case final r?) {
        unawaited(prechauffer(source));
        return VideoPlayerController.file(r, videoPlayerOptions: options);
      }
    }
    if (_enCours[source] case final arrivee?) {
      final g = await arrivee.timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (g != null) return VideoPlayerController.file(g, videoPlayerOptions: options);
    }
    unawaited(prechauffer(source));
    return VideoPlayerController.networkUrl(Uri.parse(source), videoPlayerOptions: options);
  }

  /// La garder sur le telephone, sans la lire (les reels qui suivent celui a l ecran).
  Future<File?> prechauffer(String url) {
    if (!url.startsWith('http')) return Future.value(null);
    return _enCours[url] ??= _attendreSonTour(url).whenComplete(() => _enCours.remove(url));
  }

  Future<File?> _attendreSonTour(String url) async {
    if (await gardee(url) case final f?) return f;
    if (_actifs >= _enMemeTemps) {
      final tour = Completer<void>();
      _file.add(url);
      _tours[url] = tour;
      await tour.future;
      // Plus a l ecran avant son tour : elle ne se telecharge pas pour rien.
      if (_renoncees.remove(url)) return null;
    }
    _actifs++;
    try {
      return await _telecharger(url);
    } finally {
      _actifs--;
      if (_file.isNotEmpty) _tours.remove(_file.removeAt(0))?.complete();
    }
  }

  final _tours = <String, Completer<void>>{};
  final _renoncees = <String>{};

  /// Une video prechargee qui n est plus pres de l ecran (la grille a defile) : si son tour n est
  /// pas venu, elle sort de la file.
  void renoncer(String url) {
    if (!_file.remove(url)) return;
    _renoncees.add(url);
    _tours.remove(url)?.complete();
  }

  Future<File?> _telecharger(String url) async {
    final dossier = await _ici();
    final fin = File('${dossier.path}/${_nom(url)}');
    final partiel = File('${fin.path}.part');
    try {
      final requete = await _client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final reponse = await requete.close().timeout(const Duration(seconds: 20));
      if (reponse.statusCode != 200) {
        await reponse.drain<void>();
        return null;
      }
      final sortie = partiel.openWrite();
      await reponse.timeout(const Duration(seconds: 30)).pipe(sortie);
      await partiel.rename(fin.path);
      unawaited(_menage(dossier));
      return fin;
    } catch (_) {
      if (partiel.existsSync()) unawaited(partiel.delete().then((_) {}, onError: (_) {}));
      return null;
    }
  }

  // Au-dela du plafond : les plus anciennes partent.
  Future<void> _menage(Directory dossier) async {
    try {
      final fichiers = dossier.listSync().whereType<File>().where((f) => f.path.endsWith('.mp4')).toList()..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      var total = 0;
      for (final f in fichiers) {
        total += f.lengthSync();
        if (total > _plafond) await f.delete();
      }
    } catch (_) {}
  }

  /// La place prise par les videos gardees, en octets (Reglages, Stockage).
  Future<int> taille() async {
    var total = 0;
    try {
      await for (final e in (await _ici()).list()) {
        if (e is File) total += await e.length();
      }
    } catch (_) {}
    return total;
  }

  /// Vider les videos gardees (Reglages, Stockage) : elles se retelechargeront.
  Future<void> vider() async {
    try {
      final d = await _ici();
      await d.delete(recursive: true);
      await d.create(recursive: true);
    } catch (_) {}
  }
}
