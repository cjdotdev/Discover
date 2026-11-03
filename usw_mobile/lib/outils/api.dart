// Le client de l API de USW (usw_api, /api/v1). Une seule forme d erreur,
// affichee telle quelle : { message, erreurs: { champ: [phrase] } }.
//
// L adresse du serveur : --dart-define=API=https://… ; par defaut le PC de
// developpement, joint par le cable USB (adb reverse tcp:8000 tcp:8000).
// Sans serveur joignable : ApiInjoignable, que chaque ecran dit a sa facon.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connexion.dart';
import 'langue.dart';

/// Le serveur ne repond pas (pas de reseau, serveur eteint) : on le dit, sans planter.
class ApiInjoignable implements Exception {
  const ApiInjoignable();
}

/// Une reponse d erreur de l API : son message et, pour une validation, le message de chaque champ.
class ErreurApi implements Exception {
  const ErreurApi(this.code, this.message, [this.erreurs = const {}]);

  final int code;
  final String message;
  final Map<String, String> erreurs;

  /// Le message d un champ, sinon le message general.
  String pour(String champ) => erreurs[champ] ?? message;

  @override
  String toString() => message;
}

class Reponse {
  const Reponse(this.code, this.json, [this.entetes = const {}]);

  final int code;
  final Map<String, dynamic> json;

  /// Les en-tetes de la reponse, en minuscules (upload-offset…).
  final Map<String, String> entetes;
}

class Api {
  Api._();
  static final instance = Api._();

  /// Le serveur en ligne (Railway) ; en local : --dart-define=API=http://127.0.0.1:8000/api/v1
  /// avec adb reverse tcp:8000 tcp:8000.
  static const base = String.fromEnvironment('API', defaultValue: 'https://discover-production-6cca.up.railway.app/api/v1');
  static const _cleJeton = 'jeton';
  static final _sousTest = Platform.environment.containsKey('FLUTTER_TEST');

  final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    // L IPv4 d abord (connexion.dart) : un reseau sans IPv6 ne bloque pas les requetes.
    ..connectionFactory = connecterIPv4DAbord;

  /// Dans les tests, le serveur simule : (methode, chemin, corps) -> la reponse ;
  /// il peut lever ErreurApi. Nul : aucun serveur (ApiInjoignable).
  @visibleForTesting
  static Future<Reponse> Function(String methode, String chemin, Map<String, Object?>? corps)? simulateur;

  /// Le jeton Sanctum du membre, garde sur le telephone.
  String? jeton;

  /// Un raté passager : pas de reseau, ou le serveur qui redemarre (une mise a jour). Le geste
  /// reste affiche et repart tout seul (voir [plusTard]).
  static bool passager(Object e) => e is ApiInjoignable || (e is ErreurApi && (e.code >= 500 || e.code == 429));

  // Les gestes (aimer, suivre, enregistrer) que le serveur n a pas encore recus, par cle : le
  // dernier geste sur une meme chose remplace le precedent (aimer puis ne plus aimer : un seul envoi).
  final _enAttente = <String, Future<Object?> Function()>{};
  Timer? _relance;
  int _essais = 0;
  static const _attentes = [2, 5, 10, 20, 40, 60];

  /// Renvoyer [geste] des que le serveur repond, comme les autres reseaux : rien ne se perd
  /// pendant une coupure ou une mise a jour du serveur.
  void plusTard(String cle, Future<Object?> Function() geste) {
    _enAttente[cle] = geste;
    _programmer();
  }

  /// Un geste plus recent sur la meme chose a ete recu : l ancien ne repart pas.
  void oublierEnAttente(String cle) => _enAttente.remove(cle);

  void _programmer() {
    if (_relance?.isActive ?? false) return;
    _relance = Timer(Duration(seconds: _attentes[_essais.clamp(0, _attentes.length - 1)]), _renvoyer);
  }

  Future<void> _renvoyer() async {
    for (final e in [..._enAttente.entries]) {
      try {
        await e.value();
        _essais = 0;
        if (identical(_enAttente[e.key], e.value)) _enAttente.remove(e.key);
      } catch (x) {
        if (!passager(x)) {
          // Refuse pour de bon (la publication n existe plus…) : il ne repart plus.
          if (identical(_enAttente[e.key], e.value)) _enAttente.remove(e.key);
          continue;
        }
        _essais++;
        break;
      }
    }
    if (_enAttente.isNotEmpty) _programmer();
  }

  /// Un identifiant tire au hasard pour ce telephone (en-tete X-Appareil) : les vues d un
  /// visiteur sans compte comptent une fois par jour. Il ne dit rien de la personne.
  String? appareil;

  Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      jeton = p.getString(_cleJeton);
      appareil = p.getString('appareil_id');
      if (appareil == null) {
        final hasard = Random.secure();
        appareil = List.generate(32, (_) => hasard.nextInt(16).toRadixString(16)).join();
        await p.setString('appareil_id', appareil!);
      }
    } catch (_) {}
  }

  Future<void> garderJeton(String? nouveau) async {
    jeton = nouveau;
    try {
      final p = await SharedPreferences.getInstance();
      nouveau == null ? await p.remove(_cleJeton) : await p.setString(_cleJeton, nouveau);
    } catch (_) {}
  }

  Future<Reponse> get(String chemin) => _envoyer('GET', chemin);

  Future<Reponse> post(String chemin, [Map<String, Object?> corps = const {}]) => _envoyer('POST', chemin, corps: corps);

  Future<Reponse> put(String chemin, [Map<String, Object?> corps = const {}]) => _envoyer('PUT', chemin, corps: corps);

  Future<Reponse> patch(String chemin, Map<String, Object?> corps) => _envoyer('PATCH', chemin, corps: corps);

  Future<Reponse> delete(String chemin) => _envoyer('DELETE', chemin);

  /// HEAD envois/{id} : ce que le serveur a deja recu (en-tete upload-offset).
  Future<Reponse> head(String chemin) => _envoyer('HEAD', chemin);

  /// PATCH envois/{id} : un morceau brut, a partir de `decalage`.
  Future<Reponse> morceau(String chemin, int decalage, List<int> octets) =>
      _envoyer('PATCH', chemin, brut: octets, type: 'application/offset+octet-stream', entetes: {'Upload-Offset': '$decalage'}, delai: const Duration(seconds: 60));

  /// Un fichier (la photo de profil, un son), en multipart, avec des champs en plus.
  Future<Reponse> envoyerFichier(String chemin, String champ, File fichier, {Map<String, String> champs = const {}}) async {
    final limite = '----usw${DateTime.now().microsecondsSinceEpoch}';
    final nom = fichier.path.split(Platform.pathSeparator).last;
    final octets = await fichier.readAsBytes();
    final corps = <int>[
      for (final e in champs.entries) ...utf8.encode('--$limite\r\nContent-Disposition: form-data; name="${e.key}"\r\n\r\n${e.value}\r\n'),
      ...utf8.encode('--$limite\r\nContent-Disposition: form-data; name="$champ"; filename="$nom"\r\nContent-Type: ${_type(nom)}\r\n\r\n'),
      ...octets,
      ...utf8.encode('\r\n--$limite--\r\n'),
    ];
    return _envoyer('POST', chemin, brut: corps, type: 'multipart/form-data; boundary=$limite', delai: const Duration(seconds: 60));
  }

  static String _type(String nom) {
    final n = nom.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<Reponse> _envoyer(
    String methode,
    String chemin, {
    Map<String, Object?>? corps,
    List<int>? brut,
    String? type,
    Map<String, String> entetes = const {},
    Duration delai = const Duration(seconds: 15),
  }) async {
    // Dans les tests, Flutter remplace le reseau (toute requete y repond 400) :
    // le serveur simule repond, sinon personne.
    if (_sousTest) {
      final s = simulateur;
      if (s == null) throw const ApiInjoignable();
      return s(methode, chemin, corps);
    }
    // Un rate du reseau ou du serveur (un redemarrage, une coupure d une seconde) : ce qui peut se
    // refaire sans risque (lire, mettre, retirer) est refait une fois, sans rien montrer.
    final refaisable = methode == 'GET' || methode == 'PUT' || methode == 'DELETE' || methode == 'HEAD';
    if (!refaisable || brut != null) return _une(methode, chemin, corps: corps, brut: brut, type: type, entetes: entetes, delai: delai);
    try {
      return await _une(methode, chemin, corps: corps, type: type, entetes: entetes, delai: delai);
    } on ApiInjoignable {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    } on ErreurApi catch (e) {
      if (e.code != 502 && e.code != 503 && e.code != 504) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return _une(methode, chemin, corps: corps, type: type, entetes: entetes, delai: delai);
  }

  Future<Reponse> _une(String methode, String chemin, {Map<String, Object?>? corps, List<int>? brut, String? type, Map<String, String> entetes = const {}, required Duration delai}) async {
    try {
      final requete = await _client.openUrl(methode, Uri.parse('$base/$chemin')).timeout(delai);
      requete.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        // La langue choisie : le serveur repond dans cette langue.
        ..set(HttpHeaders.acceptLanguageHeader, Langue.instance.code);
      if (jeton != null) requete.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jeton');
      if (appareil != null) requete.headers.set('X-Appareil', appareil!);
      entetes.forEach(requete.headers.set);
      final octets = brut ?? (corps == null ? null : utf8.encode(jsonEncode(corps)));
      if (octets != null) {
        requete.headers.set(HttpHeaders.contentTypeHeader, type ?? 'application/json; charset=utf-8');
        requete.contentLength = octets.length;
        requete.add(octets);
      }
      final reponse = await requete.close().timeout(delai);
      final texte = await reponse.transform(utf8.decoder).join().timeout(delai);
      final json = texte.isEmpty ? <String, dynamic>{} : (jsonDecode(texte) as Map).cast<String, dynamic>();
      if (reponse.statusCode >= 400) {
        // Le jeton n est plus valable (30 jours sans usage, deconnexion ailleurs).
        if (reponse.statusCode == 401 && jeton != null) await garderJeton(null);
        final erreurs = <String, String>{
          for (final e in ((json['erreurs'] as Map?) ?? const {}).entries)
            if (e.value is List && (e.value as List).isNotEmpty) e.key as String: (e.value as List).first as String,
        };
        throw ErreurApi(reponse.statusCode, json['message'] as String? ?? t('Une erreur s’est produite. Réessayez.'), erreurs);
      }
      final recus = <String, String>{};
      reponse.headers.forEach((nom, valeurs) => recus[nom.toLowerCase()] = valeurs.join(','));
      return Reponse(reponse.statusCode, json, recus);
    } on ErreurApi {
      rethrow;
    } on SocketException {
      throw const ApiInjoignable();
    } on TimeoutException {
      throw const ApiInjoignable();
    } on HandshakeException {
      throw const ApiInjoignable();
    } on HttpException {
      throw const ApiInjoignable();
    } on FormatException {
      throw ErreurApi(500, t('Le serveur a envoyé une réponse non valide. Réessayez.'));
    }
  }
}
