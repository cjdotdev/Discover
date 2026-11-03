import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:usw/outils/metadonnees_video.dart';

// Une boite : 4 octets de taille, 4 de type, puis le contenu.
List<int> boite(String type, List<int> contenu) {
  final t = ByteData(4)..setUint32(0, contenu.length + 8);
  return [...t.buffer.asUint8List(), ...latin1.encode(type), ...contenu];
}

List<int> u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();

List<int> mvhd(DateTime utc) {
  final secondes = utc.difference(DateTime.utc(1904)).inSeconds;
  return boite('mvhd', [0, 0, 0, 0, ...u32(secondes), ...u32(secondes), ...List.filled(88, 0)]);
}

List<int> texteUdta(String type, String texte) {
  final o = utf8.encode(texte);
  return boite(type, [...(ByteData(2)..setUint16(0, o.length)).buffer.asUint8List(), 0x15, 0xC7, ...o]);
}

List<int> meta(Map<String, String> valeurs, {bool iso = false}) {
  final cles = valeurs.keys.toList();
  final keys = boite('keys', [
    0,
    0,
    0,
    0,
    ...u32(cles.length),
    for (final c in cles) ...[...u32(utf8.encode(c).length + 8), ...latin1.encode('mdta'), ...utf8.encode(c)],
  ]);
  final ilst = boite('ilst', [
    for (var i = 0; i < cles.length; i++) ...boite(latin1.decode(u32(i + 1)), boite('data', [0, 0, 0, 1, 0, 0, 0, 0, ...utf8.encode(valeurs[cles[i]]!)])),
  ]);
  final hdlr = boite('hdlr', [0, 0, 0, 0, 0, 0, 0, 0, ...latin1.encode('mdta'), ...List.filled(13, 0)]);
  return boite('meta', [
    if (iso) ...[0, 0, 0, 0],
    ...hdlr,
    ...keys,
    ...ilst,
  ]);
}

void main() {
  test('une video d Android : la date de mvhd, la position de ©xyz, le telephone de meta/keys', () {
    final moov = Uint8List.fromList([
      ...mvhd(DateTime.utc(2026, 8, 12, 16, 40, 3)),
      ...boite('udta', [
        ...texteUdta('©xyz', '+06.3654+002.4183/'),
        ...meta({'com.android.manufacturer': 'TECNO', 'com.android.model': 'TECNO CM8'}, iso: true),
      ]),
    ]);
    final m = lireMoov(moov);
    expect(m.marque, 'TECNO');
    expect(m.modele, 'TECNO CM8');
    expect(m.date, DateTime.utc(2026, 8, 12, 16, 40, 3).toLocal());
    expect(m.latitude, closeTo(6.3654, 1e-9));
    expect(m.longitude, closeTo(2.4183, 1e-9));
  });

  test('une video d iPhone : la date et la position de com.apple.quicktime', () {
    final moov = Uint8List.fromList([
      ...mvhd(DateTime.utc(2024, 1, 1)),
      ...meta({
        'com.apple.quicktime.make': 'Apple',
        'com.apple.quicktime.model': 'iPhone 15 Pro',
        'com.apple.quicktime.location.ISO6709': '+48.8584+002.2945+035.000/',
        'com.apple.quicktime.creationdate': '2025-05-03T18:20:11+0200',
      }),
    ]);
    final m = lireMoov(moov);
    expect(m.marque, 'Apple');
    expect(m.modele, 'iPhone 15 Pro');
    expect(m.date, DateTime(2025, 5, 3, 18, 20, 11));
    expect(m.latitude, closeTo(48.8584, 1e-9));
    expect(m.longitude, closeTo(2.2945, 1e-9));
  });

  test('sans rien dans le fichier : tout reste nul (date a zero, position 0,0)', () {
    final moov = Uint8List.fromList([
      ...boite('mvhd', [0, 0, 0, 0, ...List.filled(96, 0)]),
      ...boite('udta', texteUdta('©xyz', '+00.0000+000.0000/')),
    ]);
    final m = lireMoov(moov);
    expect([m.marque, m.modele, m.date, m.latitude, m.longitude], everyElement(isNull));
  });

  test('le fichier : moov apres mdat est trouve sans lire la video', () async {
    final dossier = await Directory.systemTemp.createTemp('video');
    final f = File('${dossier.path}/v.mp4');
    await f.writeAsBytes([
      ...boite('ftyp', latin1.encode('isom0000')),
      ...boite('mdat', List.filled(300000, 7)),
      ...boite('moov', [...mvhd(DateTime.utc(2026, 3, 1, 10)), ...boite('udta', texteUdta('©xyz', '-12.5000+045.2500/'))]),
    ]);
    final m = await lireMetadonneesVideo(f.path);
    expect(m.latitude, -12.5);
    expect(m.longitude, 45.25);
    expect(m.date, DateTime.utc(2026, 3, 1, 10).toLocal());
    await dossier.delete(recursive: true);
  });
}
