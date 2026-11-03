// Le lifestyle : l album de vie de chaque membre (ce qu il mange, ce qu il fait, ses lieux). Ses
// publications ne passent pas a l accueil de Discover ; elles se voient dans son lifestyle, et
// seulement s il l a rendu visible (GET et PUT moi/lifestyle, GET lifestyles, GET
// utilisateurs/{nom}/lifestyle). Ce qu on n a pas fini de preparer reste en brouillon, ici, sur le
// telephone (ses fichiers copies a l abri), pour etre publie plus tard.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/api.dart';
import 'catalogue.dart';
import 'envois.dart';
import 'modeles.dart';

/// Un membre et son lifestyle visible : sa pile (ses 4 dernieres publications).
typedef LifestyleDeMembre = ({String pseudo, String nom, String? avatar, int nombre, List<String> photos});

/// Une publication preparee pour mon lifestyle, pas encore envoyee.
class BrouillonLifestyle {
  BrouillonLifestyle({required this.id, required this.titre, required this.couverture, required this.poidsMo, required this.source});

  final String id;
  final String titre;
  final String couverture;
  final double poidsMo;
  AEnvoyer source;

  Map<String, Object?> versJson() => {'id': id, 'titre': titre, 'couverture': couverture, 'poidsMo': poidsMo, 'source': source.versJson()};

  static BrouillonLifestyle depuisJson(Map<String, Object?> j) => BrouillonLifestyle(
    id: j['id'] as String,
    titre: j['titre'] as String? ?? '',
    couverture: j['couverture'] as String,
    poidsMo: (j['poidsMo'] as num?)?.toDouble() ?? 0,
    source: AEnvoyer.depuisJson((j['source'] as Map).cast<String, Object?>()),
  );
}

class Lifestyle extends ChangeNotifier {
  Lifestyle._();
  static final instance = Lifestyle._();

  static const _cleBrouillons = 'lifestyle_brouillons';

  /// Mon lifestyle se voit des autres (sinon, de moi seul). Nul : pas encore lu.
  bool? visible;

  /// Mes publications en ligne, les plus recentes d abord. Nul : pas encore lues.
  List<Publication>? miennes;

  final brouillons = <BrouillonLifestyle>[];

  Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      final brut = p.getString(_cleBrouillons);
      if (brut != null) {
        brouillons
          ..clear()
          ..addAll([for (final b in jsonDecode(brut) as List) BrouillonLifestyle.depuisJson((b as Map).cast<String, Object?>())]);
        // Un fichier disparu (la memoire videe) : son brouillon part avec.
        brouillons.removeWhere((b) => !File(b.source.original).existsSync());
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _garder() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_cleBrouillons, jsonEncode([for (final b in brouillons) b.versJson()]));
    } catch (_) {}
  }

  /// Mon lifestyle et son reglage, du serveur.
  Future<void> rafraichir() async {
    try {
      final r = await Api.instance.get('moi/lifestyle');
      visible = r.json['visible'] == true;
      miennes = Catalogue.instance.publicationsDepuis([for (final c in (r.json['data'] as List? ?? const []).cast<Map>()) c.cast<String, dynamic>()]);
      notifyListeners();
    } catch (_) {}
  }

  /// Rendre mon lifestyle visible des autres, ou le garder pour moi : tout de suite a l ecran.
  Future<bool> regler({required bool visible}) async {
    final avant = this.visible;
    this.visible = visible;
    notifyListeners();
    try {
      await Api.instance.put('moi/lifestyle', {'visible': visible});
      return true;
    } catch (_) {
      this.visible = avant;
      notifyListeners();
      return false;
    }
  }

  /// Les lifestyles visibles (la recherche), ceux qui ont publie le plus recemment d abord.
  Future<({List<LifestyleDeMembre> membres, String? suite})?> membres({String q = '', String? curseur}) async {
    try {
      final params = {if (q.trim().isNotEmpty) 'q': q.trim(), 'curseur': ?curseur};
      final r = await Api.instance.get(Uri(path: 'lifestyles', queryParameters: params.isEmpty ? null : params).toString());
      return (
        membres: [
          for (final m in (r.json['data'] as List? ?? const []).cast<Map>())
            (
              pseudo: ((m['auteur'] as Map?)?['nom_utilisateur'] as String?) ?? '',
              nom: ((m['auteur'] as Map?)?['nom_affiche'] as String?) ?? '',
              avatar: (m['auteur'] as Map?)?['avatar'] as String?,
              nombre: (m['nombre'] as num?)?.toInt() ?? 0,
              photos: [
                for (final p in Catalogue.instance.publicationsDepuis([for (final c in (m['photos'] as List? ?? const []).cast<Map>()) c.cast<String, dynamic>()])) p.photo,
              ],
            ),
        ],
        suite: (r.json['meta'] as Map?)?['next_cursor'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Le lifestyle d un membre (le sien s il est visible) ; nul s il est cache ou hors ligne.
  Future<List<Publication>?> deMembre(String pseudo) async {
    try {
      final r = await Api.instance.get('utilisateurs/${Uri.encodeComponent(pseudo)}/lifestyle');
      return Catalogue.instance.publicationsDepuis([for (final c in (r.json['data'] as List? ?? const []).cast<Map>()) c.cast<String, dynamic>()]);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ les brouillons

  /// Garde une publication preparee pour plus tard : ses fichiers sont copies a l abri (ceux de
  /// l appareil photo sont dans un dossier que le telephone peut vider).
  Future<void> garderBrouillon({required String titre, required double poidsMo, required AEnvoyer source}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dossier = Directory('${(await getApplicationSupportDirectory()).path}/brouillons/$id');
    await dossier.create(recursive: true);
    Future<String> copier(String chemin) async {
      final f = File(chemin);
      if (!await f.exists()) return chemin;
      return (await f.copy('${dossier.path}/${chemin.split(Platform.pathSeparator).last}')).path;
    }

    final original = await copier(source.original);
    final image = source.image == source.original ? original : await copier(source.image);
    final json = source.versJson()
      ..['original'] = original
      ..['image'] = image;
    brouillons.insert(0, BrouillonLifestyle(id: id, titre: titre, couverture: image, poidsMo: poidsMo, source: AEnvoyer.depuisJson(json)));
    notifyListeners();
    await _garder();
  }

  /// Change la legende d un brouillon.
  Future<void> legender(BrouillonLifestyle b, String legende) async {
    b.source = AEnvoyer.depuisJson(b.source.versJson()..['legende'] = legende.trim());
    notifyListeners();
    await _garder();
  }

  /// Envoie un brouillon : il rejoint les envois, et son lifestyle des qu il est en ligne.
  Future<void> publier(BrouillonLifestyle b) async {
    brouillons.remove(b);
    Envois.instance.publier(titre: b.titre, photo: b.couverture, poidsMo: b.poidsMo, source: b.source);
    notifyListeners();
    await _garder();
  }

  /// Supprime un brouillon et ses fichiers copies.
  Future<void> supprimer(BrouillonLifestyle b) async {
    brouillons.remove(b);
    notifyListeners();
    await _garder();
    try {
      await File(b.source.original).parent.delete(recursive: true);
    } catch (_) {}
  }

  /// Un autre compte sur ce telephone : mes brouillons ne passent pas au suivant.
  Future<void> oublier() async {
    for (final b in List.of(brouillons)) {
      await supprimer(b);
    }
    visible = null;
    miennes = null;
    notifyListeners();
  }
}
