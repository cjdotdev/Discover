// La sobriete : USW garde tout son verre liquide et toutes ses animations,
// meme quand le telephone chauffe (la chaleur ne bride plus rien).
//
// Android lui dit (MainActivity.kt) :
//   - si l economiseur de batterie est allume (le choix du membre) ;
//   - si c est un petit telephone (moins de 3 Go de memoire).
//   - si sa carte graphique dessine bien la lentille du verre (Vulkan) ;
//     sinon le fond derriere le verre sortait noir : le verre reste, sans lentille.
// Seulement dans les deux premiers cas, l application passe en mode leger :
//   - l ecran revient a sa frequence normale (60 Hz au lieu de 90 ou 120) ;
//   - le verre liquide perd sa lentille (plus de calcul a chaque image) ;
//   - les animations continues s arretent (piles, plan des reels, disque) ;
//   - un peu moins d images gardees en memoire.
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'langue.dart';

/// L allegement du verre : decide seul (l economiseur, un petit telephone), ou choisi.
enum ChoixLeger { automatique, toujours, jamais }

class Sobriete extends ChangeNotifier {
  Sobriete._();
  static final instance = Sobriete._();

  static const _canal = MethodChannel('bj.usw/sobriete');

  bool economie = false;
  bool petitTelephone = false;

  /// La lentille du verre se dessine bien sur ce telephone (Vulkan).
  bool lentillePossible = true;

  /// Ce que le membre a choisi dans les reglages (garde d une ouverture a l autre).
  ChoixLeger choix = ChoixLeger.automatique;

  static const _cleChoix = 'allegement_verre';

  /// Le mode leger : choisi, sinon quand le telephone economise sa batterie ou est modeste.
  bool get leger => switch (choix) {
    ChoixLeger.toujours => true,
    ChoixLeger.jamais => false,
    ChoixLeger.automatique => economie || petitTelephone,
  };

  /// Pourquoi, en une phrase (les reglages l affichent).
  String? get raison => switch (choix) {
    ChoixLeger.toujours => t('Vous avez choisi d’alléger le verre : moins d’effets, plus d’autonomie.'),
    ChoixLeger.jamais => t('Vous avez choisi de garder tout le verre, même quand l’économiseur de batterie est activé.'),
    ChoixLeger.automatique =>
      economie
          ? t('L’économiseur de batterie est activé. Discover allège le verre.')
          : petitTelephone
          ? t('Ce téléphone dispose de peu de mémoire. Discover allège le verre.')
          : null,
  };

  void choisir(ChoixLeger c) {
    if (c == choix) return;
    final avant = leger;
    choix = c;
    if (leger != avant) _memoire();
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setInt(_cleChoix, c.index)).catchError((_) => false);
  }

  Future<void> demarrer() async {
    try {
      final i = (await SharedPreferences.getInstance()).getInt(_cleChoix);
      if (i != null && i >= 0 && i < ChoixLeger.values.length) choix = ChoixLeger.values[i];
    } catch (_) {}
    // La lentille (chargee juste avant) et la memoire des images suivent ce choix tout de suite.
    if (leger) _memoire();
    notifyListeners();
    _canal.setMethodCallHandler((appel) async {
      if (appel.method == 'changement') _lire(appel.arguments);
    });
    try {
      _lire(await _canal.invokeMethod<Object?>('etat'));
    } on MissingPluginException {
      // Hors Android (tests, apercus) : rien a ecouter.
    } on PlatformException {
      // Idem.
    }
  }

  void _lire(Object? donnees) {
    if (donnees is! Map) return;
    final avant = leger;
    final e = (donnees['economie'] as bool?) ?? false;
    final p = (donnees['petitTelephone'] as bool?) ?? false;
    final l = (donnees['lentille'] as bool?) ?? true;
    // Android redit souvent la meme chose (a chaque retour dans USW) : rien ne
    // se reconstruit tant que rien ne change.
    if (e == economie && p == petitTelephone && l == lentillePossible) return;
    economie = e;
    petitTelephone = p;
    lentillePossible = l;
    if (leger != avant) {
      _memoire();
      debugPrint('SOBRIETE ${leger ? 'leger' : 'normal'} (economie $economie, petit $petitTelephone)');
    }
    notifyListeners();
  }

  // Les images decodees gardees en memoire : 100 Mo d ordinaire, 70 en leger,
  // assez pour l accueil entier. Seulement au changement de mode, et sans rien
  // vider : une image retiree de la memoire se redecode, et l ecran clignote.
  void _memoire() {
    PaintingBinding.instance.imageCache.maximumSizeBytes = leger ? 70 << 20 : 100 << 20;
  }
}
