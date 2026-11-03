// La langue de Discover : celle du telephone par defaut. Le francais (la langue des textes
// du code) et l anglais sont dans l application ; les autres langues se telechargent depuis
// le serveur (un paquet JSON de quelques dizaines de Ko), puis restent sur le telephone.
//
// Chaque texte passe par t('…') : le texte francais est la cle, le paquet donne sa traduction.
// Un texte absent du paquet reste en francais (ou en anglais si le paquet le dit).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher, TextDirection;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart' show kMaterialSupportedLanguages;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Une langue proposee par le serveur.
class PaquetLangue {
  const PaquetLangue({required this.code, required this.nom, required this.nomFr, required this.africaine, required this.aRelire, required this.version, required this.tailleKo});

  final String code;

  /// Son nom dans la langue meme (« Kiswahili ») et en francais (« Swahili »).
  final String nom;
  final String nomFr;

  /// Les langues africaines passent en premier dans la liste.
  final bool africaine;

  /// Une traduction encore a relire par un locuteur.
  final bool aRelire;
  final int version;
  final int tailleKo;

  static PaquetLangue depuisJson(Map<String, dynamic> j) => PaquetLangue(
    code: j['code'] as String,
    nom: j['nom'] as String? ?? j['code'] as String,
    nomFr: j['nom_fr'] as String? ?? j['nom'] as String? ?? '',
    africaine: j['africaine'] == true,
    aRelire: j['a_relire'] == true,
    version: (j['version'] as num?)?.toInt() ?? 1,
    tailleKo: (j['taille_ko'] as num?)?.toInt() ?? 0,
  );
}

class Langue extends ChangeNotifier {
  Langue._();
  static final instance = Langue._();

  /// Les langues dans l application, sans telechargement.
  static const incluses = {'fr': 'Français', 'en': 'English'};

  /// « systeme » (la langue du telephone) ou un code (fr, en, sw…).
  String choix = 'systeme';

  /// La langue en vigueur.
  String code = 'fr';

  /// Le nom de la langue en vigueur, dans cette langue.
  String nom = 'Français';

  /// Les langues telechargees : code -> (nom, version).
  final telechargees = <String, ({String nom, int version})>{};

  Map<String, String> _textes = const {};
  bool _droiteAGauche = false;

  static const _cleChoix = 'langue.choix';
  static const _cleTelechargees = 'langue.telechargees';

  /// La langue du telephone (« pt » pour pt_BR).
  static String get langueDuTelephone => PlatformDispatcher.instance.locale.languageCode.toLowerCase();

  Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      choix = p.getString(_cleChoix) ?? 'systeme';
      final t = jsonDecode(p.getString(_cleTelechargees) ?? '{}') as Map<String, dynamic>;
      for (final e in t.entries) {
        final v = e.value as Map;
        telechargees[e.key] = (nom: v['nom'] as String? ?? e.key, version: (v['version'] as num?)?.toInt() ?? 1);
      }
    } catch (_) {}
    await _appliquer();
    // La langue du telephone a un paquet sur le serveur : il arrive tout seul, la premiere fois.
    if (choix == 'systeme' && !incluses.containsKey(langueDuTelephone) && !telechargees.containsKey(langueDuTelephone)) {
      _telechargerSiDisponible(langueDuTelephone);
    }
  }

  Future<void> _telechargerSiDisponible(String c) async {
    final liste = await disponibles();
    final p = liste?.where((l) => l.code == c).firstOrNull;
    if (p != null && await telecharger(p) && choix == 'systeme') await _appliquer();
  }

  /// La langue a utiliser pour ce choix : la langue du telephone si elle est la, sinon l anglais
  /// (le francais pour un telephone en francais).
  String _resoudre(String c) {
    if (c != 'systeme') return incluses.containsKey(c) || telechargees.containsKey(c) ? c : 'fr';
    final s = langueDuTelephone;
    if (incluses.containsKey(s) || telechargees.containsKey(s)) return s;
    return 'en';
  }

  Future<void> _appliquer() async {
    final c = _resoudre(choix);
    Map<String, dynamic>? paquet;
    if (c != 'fr') {
      try {
        paquet = c == 'en' ? jsonDecode(await rootBundle.loadString('assets/langues/en.json')) as Map<String, dynamic> : jsonDecode(await (await _fichier(c)).readAsString()) as Map<String, dynamic>;
      } catch (_) {
        paquet = null;
      }
    }
    if (c != 'fr' && paquet == null) {
      // Un paquet illisible (efface, abime) : le francais, et on l oublie.
      telechargees.remove(c);
      await _garderTelechargees();
      return _appliquerFrancais();
    }
    code = c;
    nom = paquet?['nom'] as String? ?? incluses[c] ?? c;
    _textes = paquet == null ? const {} : ((paquet['textes'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String));
    _droiteAGauche = paquet?['rtl'] == true;
    notifyListeners();
  }

  void _appliquerFrancais() {
    code = 'fr';
    nom = 'Français';
    _textes = const {};
    _droiteAGauche = false;
    notifyListeners();
  }

  /// La langue du telephone a change : on la suit si le choix est « Langue du téléphone ».
  Future<void> suivreLeTelephone() async {
    if (choix == 'systeme') await _appliquer();
  }

  /// Changer de langue (« systeme », fr, en, ou une langue telechargee).
  Future<void> choisir(String c) async {
    choix = c;
    try {
      (await SharedPreferences.getInstance()).setString(_cleChoix, c);
    } catch (_) {}
    await _appliquer();
  }

  /// Les langues proposees par le serveur : les africaines d abord, puis les autres, chacune
  /// par ordre alphabetique de son nom. Nul hors ligne.
  Future<List<PaquetLangue>?> disponibles() async {
    try {
      final r = await Api.instance.get('langues');
      final l = [for (final j in (r.json['data'] as List? ?? []).cast<Map>()) PaquetLangue.depuisJson(j.cast<String, dynamic>())];
      l.sort((a, b) => a.africaine != b.africaine ? (a.africaine ? -1 : 1) : _sansAccents(a.nom).compareTo(_sansAccents(b.nom)));
      return l;
    } catch (_) {
      return null;
    }
  }

  /// Telecharger une langue (ou sa nouvelle version) ; vrai si elle est sur le telephone.
  Future<bool> telecharger(PaquetLangue p) async {
    try {
      final r = await Api.instance.get('langues/${Uri.encodeComponent(p.code)}');
      final j = r.json;
      if (j['textes'] is! Map) return false;
      await (await _fichier(p.code)).writeAsString(jsonEncode(j), flush: true);
      telechargees[p.code] = (nom: p.nom, version: (j['version'] as num?)?.toInt() ?? p.version);
      await _garderTelechargees();
      if (code == p.code) await _appliquer();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retirer une langue telechargee ; si c etait la langue en vigueur, retour a celle du telephone.
  Future<void> retirer(String c) async {
    telechargees.remove(c);
    await _garderTelechargees();
    try {
      final f = await _fichier(c);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (choix == c) return choisir('systeme');
    await _appliquer();
  }

  Future<void> _garderTelechargees() async {
    try {
      (await SharedPreferences.getInstance()).setString(
        _cleTelechargees,
        jsonEncode({
          for (final e in telechargees.entries) e.key: {'nom': e.value.nom, 'version': e.value.version},
        }),
      );
    } catch (_) {}
  }

  static Future<File> _fichier(String c) async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/langues');
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}/$c.json');
  }

  static String _sansAccents(String s) =>
      s.toLowerCase().replaceAll(RegExp('[àáâä]'), 'a').replaceAll(RegExp('[èéêë]'), 'e').replaceAll(RegExp('[ìíîï]'), 'i').replaceAll(RegExp('[òóôö]'), 'o').replaceAll(RegExp('[ùúûü]'), 'u');

  /// La locale des widgets de Flutter (calendrier, champs) : la langue si Flutter la connait,
  /// sinon l anglais (le francais pour un texte encore en francais).
  Locale get localeMaterial => Locale(kMaterialSupportedLanguages.contains(code) ? code : (code == 'fr' ? 'fr' : 'en'));

  /// Le sens d ecriture (arabe : de droite a gauche).
  TextDirection get sens => _droiteAGauche ? TextDirection.rtl : TextDirection.ltr;

  /// Le texte dans la langue en vigueur ; {nom} est remplace par sa valeur.
  String traduire(String fr, [Map<String, Object?>? valeurs]) {
    var s = _textes[fr] ?? fr;
    if (valeurs != null) {
      for (final e in valeurs.entries) {
        s = s.replaceAll('{${e.key}}', '${e.value}');
      }
    }
    return s;
  }
}

/// Un texte de l application, dans la langue choisie : t('Enregistrer'), t('{n} abonnés', {'n': 3}).
String t(String fr, [Map<String, Object?>? valeurs]) => Langue.instance.traduire(fr, valeurs);

/// Au singulier ou au pluriel selon [n] : tn(n, '{n} abonné', '{n} abonnés').
String tn(int n, String un, String plusieurs) => Langue.instance.traduire(n == 1 || n == 0 && Langue.instance.code == 'fr' ? un : plusieurs, {'n': n});
