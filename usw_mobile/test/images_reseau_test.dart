// Une image du serveur doit toujours finir de charger, bien ou mal : un chargement qui
// s attendait lui-meme (whenComplete qui rendait sa propre tache) laissait toutes les
// photos noires, sans erreur, a l accueil, sur la page photo et dans les notifications.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usw/outils/images_reseau.dart';

/// Un serveur d images local qui ne connait aucune image (404).
Future<HttpServer> _serveurVide() async {
  final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  serveur.listen(
    (r) => r.response
      ..statusCode = 404
      ..close(),
  );
  return serveur;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('une image absente du serveur finit en erreur, au lieu de rester en attente', () async {
    final dossier = await Directory.systemTemp.createTemp('images_reseau_test');
    final serveur = await _serveurVide();
    addTearDown(() async {
      await serveur.close(force: true);
      await dossier.delete(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dossier.path);
    final adresse = 'http://127.0.0.1:${serveur.port}/contenus/absente/480.webp';
    await expectLater(ImagesReseau.octets(adresse).timeout(const Duration(seconds: 10)), throwsA(isA<HttpException>()));
  });
}
