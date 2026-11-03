// Les lieux enregistres : PUT et DELETE moi/lieux/{id}, la liste par GET moi/lieux
// (chaque lieu avec sa pile, comme a l accueil). Qu un lieu soit enregistre ou non
// se lit dans GET lieux/{id} (enregistre), une fois connecte.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../outils/api.dart';
import 'modeles.dart';
import '../outils/langue.dart';

class LieuxEnregistres extends ChangeNotifier {
  LieuxEnregistres._();
  static final instance = LieuxEnregistres._();

  // Ce que l on sait de chaque lieu : enregistre ou non (absent : pas encore lu).
  final _etat = <String, bool>{};

  bool? estEnregistre(String id) => _etat[id];

  /// Le serveur dit si le lieu est enregistre ; nul sans compte, ou s il n a pas repondu.
  Future<bool?> lire(String id) async {
    if (Api.instance.jeton == null) return null;
    try {
      final r = await Api.instance.get('lieux/${Uri.encodeComponent(id)}');
      final oui = (r.json['data'] as Map?)?['enregistre'];
      if (oui is bool) _etat[id] = oui;
    } catch (_) {
      // Hors ligne : on garde ce qu on savait.
    }
    return _etat[id];
  }

  /// Enregistrer (ou retirer) un lieu. Faux si le serveur ne l a pas fait : rien ne change.
  Future<bool> enregistrer(String id, bool oui) async {
    if (Api.instance.jeton == null) return false;
    final chemin = 'moi/lieux/${Uri.encodeComponent(id)}';
    try {
      oui ? await Api.instance.put(chemin) : await Api.instance.delete(chemin);
    } catch (_) {
      return false;
    }
    _etat[id] = oui;
    notifyListeners();
    return true;
  }

  /// Une page de mes lieux enregistres et le curseur de la suivante ; nul sans compte ou hors ligne.
  /// `retires` : les noms des lieux sortis de la liste parce que toutes leurs photos ont ete
  /// supprimees (le serveur les retire chez tous ceux qui les avaient enregistres, et le dit une fois).
  Future<({List<Lieu> lieux, String? suite, List<String> retires})?> page([String? curseur]) async {
    if (Api.instance.jeton == null) return null;
    try {
      final r = await Api.instance.get('moi/lieux${curseur == null ? '' : '?curseur=${Uri.encodeQueryComponent(curseur)}'}');
      final lieux = [for (final l in (r.json['data'] as List? ?? []).cast<Map>()) _lieuDe(l.cast<String, dynamic>())];
      for (final l in lieux) {
        _etat[l.id] = true;
      }
      final retires = <String>[];
      for (final x in (r.json['retires'] as List? ?? []).cast<Map>()) {
        final id = x['id'] as String?;
        if (id != null) _etat[id] = false;
        retires.add(x['nom'] as String? ?? '');
      }
      return (lieux: lieux, suite: (r.json['meta'] as Map?)?['next_cursor'] as String?, retires: retires);
    } catch (_) {
      return null;
    }
  }

  // Un lieu du serveur (LieuResource) et sa pile : la petite taille de chaque photo.
  static Lieu _lieuDe(Map<String, dynamic> j) {
    final photos = <String>[];
    double? ratio;
    for (final p in (j['photos'] as List? ?? []).cast<Map>()) {
      final images = (p['images'] as Map?) ?? const {};
      final tailles = p['type'] == 'reel' ? const ['affiche', '480', '1080'] : const ['1080', '2160', '480'];
      final url = [for (final t in tailles) (images[t] as Map?)?['url']].whereType<String>().where((u) => u.isNotEmpty).firstOrNull;
      if (url == null) continue;
      final r = (p['ratio'] as num?)?.toDouble();
      if (r != null && r > 0) {
        ratiosFichiers[url] = r;
        ratio ??= r;
      }
      photos.add(url);
    }
    return Lieu(
      id: j['id'] as String,
      nom: j['nom'] as String? ?? '',
      region: j['region'] as String? ?? '',
      photos: photos,
      // Les publications de sa pile : les reels filmes dans Discover sont dans les Reels.
      nombre: math.max(0, ((j['nombre_contenus'] as num?)?.toInt() ?? photos.length) - ((j['nombre_reels'] as num?)?.toInt() ?? 0)),
      ratio: (ratio ?? 0.75).clamp(0.75, 1.0).toDouble(),
      type: j['type'] as String? ?? '',
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
      situe: j['situe'] != false && j['latitude'] != null,
      pays: j['pays'] as String?,
      nombreReels: (j['nombre_reels'] as num?)?.toInt(),
    );
  }
}

/// « 1 publication », « 12 publications » : photos et reels ensemble.
String nombrePublications(int n) => tn(n, '{n} publication', '{n} publications');
