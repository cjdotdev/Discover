import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/routes.dart';

/// Ce que l'application garde d'un lancement à l'autre : le jeton, le profil, la bienvenue vue.
class Session extends ChangeNotifier {
  Session._();

  static final instance = Session._();

  static const _cleJeton = 'jeton';
  static const _cleProfil = 'profil_complet';
  static const _cleBienvenue = 'bienvenue_vue';

  String? jeton;
  bool profilComplet = false;
  bool bienvenueVue = false;

  bool get connecte => jeton != null;

  /// La première page après l'ouverture.
  String get destination {
    if (!bienvenueVue) return Routes.bienvenue;
    if (!connecte) return Routes.entree;
    return profilComplet ? Routes.accueil : Routes.completerProfil;
  }

  Future<void> charger() async {
    final preferences = await SharedPreferences.getInstance();
    jeton = preferences.getString(_cleJeton);
    profilComplet = preferences.getBool(_cleProfil) ?? false;
    bienvenueVue = preferences.getBool(_cleBienvenue) ?? false;
  }

  Future<void> ouvrir({required String jeton, required bool profilComplet}) async {
    this.jeton = jeton;
    this.profilComplet = profilComplet;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cleJeton, jeton);
    await preferences.setBool(_cleProfil, profilComplet);
    notifyListeners();
  }

  Future<void> marquerProfilComplet() async {
    profilComplet = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_cleProfil, true);
    notifyListeners();
  }

  Future<void> marquerBienvenueVue() async {
    bienvenueVue = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_cleBienvenue, true);
  }

  Future<void> fermer() async {
    jeton = null;
    profilComplet = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cleJeton);
    await preferences.remove(_cleProfil);
    notifyListeners();
  }
}
