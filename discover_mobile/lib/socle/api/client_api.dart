import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../session/session.dart';
import 'erreur_api.dart';

/// Parle à l'API Laravel : ajoute le jeton, décode le JSON, transforme les erreurs en exceptions.
/// L'adresse se donne au lancement : flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1
class ClientApi {
  ClientApi({http.Client? client}) : _client = client ?? http.Client();

  static const adresse = String.fromEnvironment('API_URL');

  /// Sans adresse, l'application tourne avec les données simulées.
  static bool get configuree => adresse.isNotEmpty;

  final http.Client _client;

  Future<Map<String, dynamic>> get(String chemin) => _envoyer(() => _client.get(_url(chemin), headers: _entetes));

  Future<Map<String, dynamic>> post(String chemin, [Map<String, dynamic> corps = const {}]) =>
      _envoyer(() => _client.post(_url(chemin), headers: _entetes, body: jsonEncode(corps)));

  Future<Map<String, dynamic>> patch(String chemin, Map<String, dynamic> corps) =>
      _envoyer(() => _client.patch(_url(chemin), headers: _entetes, body: jsonEncode(corps)));

  /// Envoie un fichier (la photo de profil, par exemple).
  Future<Map<String, dynamic>> postFichier(String chemin, String champ, List<int> octets, String nom) {
    return _envoyer(() async {
      final requete = http.MultipartRequest('POST', _url(chemin))
        ..headers.addAll(_entetes)
        ..files.add(http.MultipartFile.fromBytes(champ, octets, filename: nom));
      return http.Response.fromStream(await _client.send(requete));
    });
  }

  Uri _url(String chemin) => Uri.parse('$adresse/$chemin');

  Map<String, String> get _entetes => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (Session.instance.jeton != null) 'Authorization': 'Bearer ${Session.instance.jeton}',
  };

  Future<Map<String, dynamic>> _envoyer(Future<http.Response> Function() requete) async {
    final http.Response reponse;
    try {
      reponse = await requete().timeout(const Duration(seconds: 20));
    } on http.ClientException {
      throw const ApiInjoignable();
    } on TimeoutException {
      throw const ApiInjoignable();
    }

    final json = reponse.body.isEmpty ? <String, dynamic>{} : jsonDecode(reponse.body) as Map<String, dynamic>;
    if (reponse.statusCode < 400) return json;

    // Le jeton n'est plus valable : on oublie la session.
    if (reponse.statusCode == 401) await Session.instance.fermer();

    final erreurs = (json['erreurs'] as Map<String, dynamic>?) ?? {};
    throw ErreurApi(
      reponse.statusCode,
      json['message'] as String? ?? 'Une erreur est survenue.',
      erreurs.map((champ, liste) => MapEntry(champ, List<String>.from(liste as List))),
    );
  }
}
