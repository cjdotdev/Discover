// Les vues : ce que le membre a regarde, envoye au serveur par petits paquets (POST vues).
// Le serveur decide de ce qui compte (2 s pour une photo, 3 s pour un reel, une fois par
// personne et par jour, pas ses propres publications) ; ici, on mesure seulement le temps
// passe devant, et si un reel a ete regarde jusqu au bout. Hors ligne, les vues attendent.
// Le serveur repond avec le nombre de vues a jour de chaque publication du paquet : les
// compteurs des ecrans suivent sans recharger (nombre).
import 'package:flutter/widgets.dart';

import '../outils/api.dart';

class Vues extends ChangeNotifier with WidgetsBindingObserver {
  Vues._();
  static final instance = Vues._();

  /// En attente d envoi : le temps le plus long, et « jusqu au bout », par publication.
  final _attente = <String, ({int ms, bool complete})>{};
  bool _ecoute = false;

  /// Depuis quand le paquet attend (nul : vide), et pas de nouvel essai avant [_pasAvant].
  DateTime? _depuis;
  DateTime? _pasAvant;

  /// Le dernier nombre de vues donne par le serveur, par publication.
  final _connus = <String, int>{};

  /// Le nombre de vues a montrer : le plus recent connu (il ne fait que monter), sinon celui
  /// de la publication telle qu elle est arrivee.
  int nombre(String? contenu, int duServeur) {
    final connu = contenu == null ? null : _connus[contenu];
    return connu != null && connu > duServeur ? connu : duServeur;
  }

  void _retenir(Object? vues) {
    if (vues is! Map) return;
    var change = false;
    vues.forEach((k, v) {
      if (k is String && v is num && _connus[k] != v.toInt()) {
        _connus[k] = v.toInt();
        change = true;
      }
    });
    if (change) notifyListeners();
  }

  /// Redemande le nombre de vues d une publication (une duree de 0 ne compte pas).
  Future<void> actualiser(String contenu) async {
    try {
      _retenir(
        (await Api.instance.post('vues', {
          'vues': [
            {'contenu': contenu, 'duree_ms': 0},
          ],
        })).json['vues'],
      );
    } catch (_) {}
  }

  /// Qui a vu ma publication (seul son auteur le peut) : les membres, les plus recents
  /// d abord, et le nombre de visiteurs sans compte. Nul : le serveur n a pas repondu.
  Future<({int total, int sansCompte, List<({String pseudo, String nom, String? avatar, DateTime? vuLe})> membres})?> spectateurs(String contenu) async {
    try {
      final r = await Api.instance.get('contenus/$contenu/spectateurs');
      final total = (r.json['total'] as num?)?.toInt() ?? 0;
      _retenir({contenu: total});
      return (
        total: total,
        sansCompte: (r.json['sans_compte'] as num?)?.toInt() ?? 0,
        membres: [
          for (final m in (r.json['data'] as List? ?? []).cast<Map>())
            (
              pseudo: (m['membre'] as Map)['nom_utilisateur'] as String? ?? '',
              nom: ((m['membre'] as Map)['nom_affiche'] as String?) ?? ((m['membre'] as Map)['nom_utilisateur'] as String? ?? ''),
              avatar: (m['membre'] as Map)['avatar'] as String?,
              vuLe: DateTime.tryParse(m['vu_le'] as String? ?? '')?.toLocal(),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  /// Une publication regardee pendant [duree] (un reel : [complete] s il a ete vu en entier).
  void noter(String contenu, Duration duree, {bool complete = false}) {
    if (duree.inMilliseconds < 1000) return;
    if (!_ecoute) {
      _ecoute = true;
      WidgetsBinding.instance.addObserver(this);
    }
    final avant = _attente[contenu];
    _attente[contenu] = (ms: avant == null || duree.inMilliseconds > avant.ms ? duree.inMilliseconds : avant.ms, complete: complete || (avant?.complete ?? false));
    _depuis ??= DateTime.now();
    // Sans minuteur : le paquet part quand il a 20 secondes ou 50 vues, et toujours quand
    // l application passe en arriere-plan. Peu de requetes, rien de perdu.
    final maintenant = DateTime.now();
    final pret = _attente.length >= 50 || maintenant.difference(_depuis!) >= const Duration(seconds: 20);
    if (pret && (_pasAvant == null || maintenant.isAfter(_pasAvant!))) envoyer();
  }

  Future<void> envoyer() async {
    if (_attente.isEmpty) return;
    final paquet = Map.of(_attente);
    _attente.clear();
    _depuis = null;
    try {
      final r = await Api.instance.post('vues', {
        'vues': [
          for (final e in paquet.entries.take(50)) {'contenu': e.key, 'duree_ms': e.value.ms, 'complete': e.value.complete},
        ],
      });
      _pasAvant = null;
      _retenir(r.json['vues']);
      // Plus de 50 d un coup : le reste au paquet suivant.
      for (final e in paquet.entries.skip(50)) {
        _attente[e.key] = e.value;
      }
      if (_attente.isNotEmpty) _depuis = DateTime.now();
    } on ApiInjoignable {
      // Hors ligne : on reessaie dans une minute au plus tot, sans rien perdre.
      paquet.forEach((k, v) => _attente.putIfAbsent(k, () => v));
      _depuis ??= DateTime.now();
      _pasAvant = DateTime.now().add(const Duration(minutes: 1));
    } catch (_) {
      // Refusees (trop de requetes, publication retiree) : elles ne comptent pas.
    }
  }

  // L application passe en arriere-plan : le paquet part tout de suite.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) envoyer();
  }
}
