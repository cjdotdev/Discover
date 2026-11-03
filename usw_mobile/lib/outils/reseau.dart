// Le reseau et les choix du membre pour les donnees mobiles (Reglages, Donnees et reseau).
// Android dit si la connexion est facturee a l usage (donnees mobiles) ; les trois choix
// s appliquent seulement dans ce cas : en Wi-Fi, tout se charge normalement.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Reseau extends ChangeNotifier {
  Reseau._();
  static final instance = Reseau._();

  static const _canal = MethodChannel('bj.usw/reseau');

  /// Connecte a internet (vrai tant qu Android n a rien dit).
  bool connecte = true;

  /// Sur une connexion facturee a l usage (donnees mobiles, partage de connexion).
  bool limite = false;

  /// Photos plus legeres sur les donnees mobiles.
  bool economie = false;

  /// Les reels se lisent au toucher, sur les donnees mobiles.
  bool reelsWifi = false;

  /// Les envois attendent le Wi-Fi.
  bool envoisWifi = false;

  /// Les envois continuent quand on quitte Discover (une notification montre leur avancee).
  bool envoisEnFond = true;

  bool get photosLegeres => economie && limite;
  bool get reelsAuToucher => reelsWifi && limite;
  bool get envoisEnAttente => envoisWifi && limite;

  Future<void> demarrer() async {
    try {
      final p = await SharedPreferences.getInstance();
      economie = p.getBool('reseau_economie') ?? false;
      reelsWifi = p.getBool('reseau_reels_wifi') ?? false;
      envoisWifi = p.getBool('reseau_envois_wifi') ?? false;
      envoisEnFond = p.getBool('reseau_envois_fond') ?? true;
    } catch (_) {}
    _canal.setMethodCallHandler((appel) async {
      if (appel.method == 'change') _appliquer(appel.arguments);
    });
    try {
      _appliquer(await _canal.invokeMethod<Object?>('etat'));
    } catch (_) {
      // Pas Android (tests, iOS pour l instant) : on fait comme en Wi-Fi.
    }
  }

  void _appliquer(Object? brut) {
    if (brut is! Map) return;
    final c = brut['connecte'] == true;
    final l = brut['limite'] == true;
    if (c == connecte && l == limite) return;
    connecte = c;
    limite = l;
    notifyListeners();
  }

  Future<void> choisir({bool? economie, bool? reelsWifi, bool? envoisWifi, bool? envoisEnFond}) async {
    this.economie = economie ?? this.economie;
    this.reelsWifi = reelsWifi ?? this.reelsWifi;
    this.envoisWifi = envoisWifi ?? this.envoisWifi;
    this.envoisEnFond = envoisEnFond ?? this.envoisEnFond;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('reseau_economie', this.economie);
      await p.setBool('reseau_reels_wifi', this.reelsWifi);
      await p.setBool('reseau_envois_wifi', this.envoisWifi);
      await p.setBool('reseau_envois_fond', this.envoisEnFond);
    } catch (_) {}
  }
}
