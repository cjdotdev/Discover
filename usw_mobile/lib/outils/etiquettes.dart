// Ce qu on voit sur une photo, lu par le telephone lui-meme (Google ML Kit, hors connexion, la
// photo ne part nulle part) : « Forest », « Beach », « Food »… Les etiquettes partent avec la
// publication ; la recherche (« arbre ») et les gouts choisis a l inscription s en servent.
// Le telephone de l equipe rattrape aussi les photos publiees avant (sans etiquettes).
import 'dart:async';
import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'images_reseau.dart';

class Etiquettes {
  Etiquettes._();
  static final instance = Etiquettes._();

  ImageLabeler? _lecteur;

  /// Ce que le telephone voit sur l image de [chemin] (une photo, ou l affiche d un reel), les plus
  /// sures d abord ; vide si rien n est sur (ou si la lecture echoue : la publication part quand meme).
  Future<List<Map<String, Object>>> lire(String chemin) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return const [];
    try {
      final lecteur = _lecteur ??= ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final vues = await lecteur.processImage(InputImage.fromFilePath(chemin)).timeout(const Duration(seconds: 8));
      vues.sort((a, b) => b.confidence.compareTo(a.confidence));
      return [
        for (final v in vues.take(20)) {'nom': v.label, 'confiance': double.parse(v.confidence.toStringAsFixed(3))},
      ];
    } catch (_) {
      return const [];
    }
  }

  bool _rattrapage = false;

  /// Le telephone de l equipe lit les photos publiees avant les etiquettes, 30 par tour, sans gener :
  /// une a la fois, en arriere-plan.
  Future<void> rattraper() async {
    if (_rattrapage) return;
    _rattrapage = true;
    try {
      final dossier = await getTemporaryDirectory();
      for (var tour = 0; tour < 20; tour++) {
        final r = await Api.instance.get('moderation/a-etiqueter');
        final liste = (r.json['data'] as List? ?? const []).cast<Map>();
        if (liste.isEmpty) return;
        for (final c in liste) {
          final id = c['id'] as String, image = c['image'] as String;
          final f = File('${dossier.path}/etiquette_$id.img');
          try {
            await f.writeAsBytes(await ImagesReseau.octets(image));
            final vues = await lire(f.path);
            await Api.instance.put('moderation/contenus/$id/etiquettes', {'etiquettes': vues});
          } catch (_) {
            // Celle-ci attendra le prochain tour.
          } finally {
            if (f.existsSync()) unawaited(f.delete().then((_) {}, onError: (_) {}));
          }
        }
      }
    } catch (_) {
      // Pas de reseau, ou pas de l equipe : on reessaiera a la prochaine ouverture.
    } finally {
      _rattrapage = false;
    }
  }
}
