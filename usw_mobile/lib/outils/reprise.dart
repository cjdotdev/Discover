// La reprise : pendant que l appareil photo du telephone est ouvert, Android
// peut fermer USW pour liberer de la memoire. La photo ou la video n est pas
// perdue : image_picker la garde, et USW la reprend au demarrage, la ou on en
// etait (la publication, le montage du reel ou la photo de profil).
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appareil.dart';

enum Prise { photo, reel, profil }

const _cle = 'prise_en_cours';

/// Avant d ouvrir l appareil photo : ce qu on est en train de prendre.
Future<void> noterPrise(Prise prise) async {
  try {
    await (await SharedPreferences.getInstance()).setString(_cle, '${prise.name} ${DateTime.now().millisecondsSinceEpoch}');
  } catch (_) {}
}

/// Au retour de l appareil photo, USW etait encore la : rien a reprendre.
Future<void> finPrise() async {
  try {
    await (await SharedPreferences.getInstance()).remove(_cle);
  } catch (_) {}
}

/// La prise retrouvee au demarrage (le fichier) ; la coquille des onglets la reprend.
(Prise, String)? priseRetrouvee;

/// Au demarrage : une prise etait en cours quand USW a ete ferme ?
Future<void> chercherPriseRetrouvee() async {
  if (!Platform.isAndroid) return;
  try {
    final preferences = await SharedPreferences.getInstance();
    final note = preferences.getString(_cle)?.split(' ');
    // Rien de note : on ne demande rien a Android (le cas de chaque ouverture).
    if (note == null) return;
    await preferences.remove(_cle);
    final prise = Prise.values.byName(note.first);
    if (prise == Prise.profil) {
      // La photo de profil passe par l ecran reduit d Android : image_picker la garde.
      final perdu = await ImagePicker().retrieveLostData();
      final fichier = perdu.file;
      if (!perdu.isEmpty && fichier != null) priseRetrouvee = (prise, fichier.path);
      return;
    }
    // La photo ou le reel : ce que l appareil photo a ajoute a la galerie depuis.
    final depuis = DateTime.fromMillisecondsSinceEpoch(int.tryParse(note.length > 1 ? note[1] : '') ?? 0);
    final prises = await Appareil.depuis(depuis);
    if (prises.isNotEmpty) priseRetrouvee = (prise, prises.first.chemin);
  } catch (_) {}
}
