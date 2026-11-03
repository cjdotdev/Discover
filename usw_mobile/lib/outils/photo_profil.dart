// La photo de profil : prise avec l appareil photo (camera de face) ou choisie
// dans la galerie, puis copiee dans le dossier de l application (le cache
// d image_picker peut etre vide par Android). Le lot 1 l enverra a l API.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../donnees/session.dart';
import '../widgets/banniere.dart';
import '../widgets/feuille.dart';
import 'langue.dart';
import 'reprise.dart';

const _cle = Session.clePhotoProfil;

/// Au demarrage : la photo choisie la derniere fois, si elle est toujours la.
Future<void> chargerPhotoProfil() async {
  try {
    final chemin = (await SharedPreferences.getInstance()).getString(_cle);
    if (chemin != null && File(chemin).existsSync()) Session.instance.photo = chemin;
  } catch (_) {}
}

Future<void> _garder(String? chemin) async {
  Session.instance.changerPhoto(chemin);
  try {
    final p = await SharedPreferences.getInstance();
    chemin == null ? await p.remove(_cle) : await p.setString(_cle, chemin);
  } catch (_) {}
}

/// La photo choisie est copiee dans le dossier de l application, puis gardee.
Future<void> garderPhotoProfil(String chemin) async {
  final dossier = await getApplicationDocumentsDirectory();
  // Un nom neuf a chaque fois : l ancienne image en cache ne reste pas affichee.
  final cible = File('${dossier.path}/profil-${DateTime.now().millisecondsSinceEpoch}.jpg');
  await File(chemin).copy(cible.path);
  final ancienne = Session.instance.photo;
  await _garder(cible.path);
  if (ancienne != null) File(ancienne).delete().ignore();
}

Future<void> _prendre(BuildContext context, ImageSource source) async {
  await noterPrise(Prise.profil);
  try {
    final image = await ImagePicker().pickImage(source: source, maxWidth: 1080, maxHeight: 1080, imageQuality: 88, preferredCameraDevice: CameraDevice.front);
    await finPrise();
    if (image == null) return;
    await garderPhotoProfil(image.path);
    // Deja connecte (Modifier le profil) : elle part tout de suite au serveur (sinon, a la
    // prochaine ouverture : la session la garde a envoyer).
    if (Session.instance.connecte && Session.instance.profilComplete) Session.instance.envoyerPhoto().catchError((_) {});
    if (context.mounted) bulle(context, t('Photo de profil mise à jour.'), icone: 'coche');
  } catch (_) {
    await finPrise();
    if (context.mounted) {
      bulle(context, source == ImageSource.camera ? t("Impossible d'ouvrir l'appareil photo.") : t("Impossible d'ouvrir la galerie."), icone: 'alerte');
    }
  }
}

/// La feuille : prendre une photo, choisir dans la galerie, ou retirer.
Future<void> choisirPhotoProfil(BuildContext context) => montrerFeuille<void>(
  context,
  titre: t('Photo de profil'),
  contenu: (f) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LigneFeuille(
          icone: 'camera',
          texte: t('Prendre une photo'),
          onTap: () {
            Navigator.pop(f);
            _prendre(context, ImageSource.camera);
          },
        ),
        LigneFeuille(
          icone: 'image',
          texte: t('Choisir dans la galerie'),
          onTap: () {
            Navigator.pop(f);
            _prendre(context, ImageSource.gallery);
          },
        ),
        // Une photo ici, ou seulement sur le serveur (apres une reinstallation).
        if (Session.instance.photo != null || Session.instance.avatar != null)
          LigneFeuille(
            icone: 'poubelle',
            texte: t('Retirer la photo'),
            danger: true,
            onTap: () async {
              Navigator.pop(f);
              final ancienne = Session.instance.photo;
              await _garder(null);
              if (ancienne != null) File(ancienne).delete().ignore();
              try {
                await Session.instance.retirerPhoto();
              } catch (_) {
                if (context.mounted) bulle(context, t('Impossible de retirer la photo. Réessayez.'), icone: 'alerte');
              }
            },
          ),
      ],
    ),
  ),
);
