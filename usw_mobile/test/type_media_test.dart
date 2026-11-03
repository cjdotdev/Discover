import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:usw/outils/type_media.dart';

void main() {
  late Directory dossier;

  setUp(() => dossier = Directory.systemTemp.createTempSync('type_media'));
  tearDown(() => dossier.deleteSync(recursive: true));

  Future<TypeMedia?> type(String nom, List<int> octets) {
    final f = File('${dossier.path}/$nom')..writeAsBytesSync(octets);
    return typeDeMedia(f.path);
  }

  List<int> boite(String marque) => [0, 0, 0, 24, ...'ftyp'.codeUnits, ...marque.codeUnits, 0, 0, 0, 0];

  test('les photos et les videos sont reconnues a leur contenu, pas a leur nom', () async {
    expect(await type('a.jpg', [0xFF, 0xD8, 0xFF, 0xE0, 0, 0]), TypeMedia.photo);
    expect(await type('a.png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]), TypeMedia.photo);
    expect(await type('a.webp', [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]), TypeMedia.photo);
    expect(await type('a.heic', boite('heic')), TypeMedia.photo);
    expect(await type('a.mp4', boite('isom')), TypeMedia.video);
    expect(await type('a.mov', boite('qt  ')), TypeMedia.video);
    expect(await type('a.webm', [0x1A, 0x45, 0xDF, 0xA3, 0, 0]), TypeMedia.video);
    // Un JPEG nomme .txt reste une photo.
    expect(await type('photo.txt', [0xFF, 0xD8, 0xFF, 0xE1]), TypeMedia.photo);
  });

  test('un texte, un PDF ou un fichier vide ne sont pas publies', () async {
    expect(await type('notes.txt', 'Bonjour Discover'.codeUnits), isNull);
    expect(await type('doc.jpg', '%PDF-1.7'.codeUnits), isNull);
    expect(await type('vide.mp4', []), isNull);
    expect(await typeDeMedia('${dossier.path}/absent.jpg'), isNull);
  });
}
