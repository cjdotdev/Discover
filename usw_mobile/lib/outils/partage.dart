// Le partage vers les autres applications du telephone : WhatsApp, les SMS,
// l e-mail, et la feuille de partage d Android (avec la photo elle-meme).
// Rien ne passe par le serveur : le lien suffit, il ouvre la photo meme sans
// l application.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'images_reseau.dart';
import 'langue.dart';

/// Le domaine des liens partages : ses pages montrent la photo (et son apercu dans WhatsApp),
/// et ouvrent Discover sur Android s il est installe (/l/ un lieu, /p/ une publication,
/// /@ un createur, /c/ une collection).
const domainePublic = 'discover.simeonamoussou.com';

/// Le texte partage : le titre et le lien complet.
String texteDePartage(String titre, String lien) => t('{titre} sur Discover : https://{lien}', {'titre': titre, 'lien': lien});

Future<bool> _ouvrir(Uri adresse) async {
  try {
    return await launchUrl(adresse, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}

/// WhatsApp, l application si elle est la, sinon wa.me dans le navigateur.
Future<bool> partagerWhatsApp(String texte) async =>
    await _ouvrir(Uri.parse('whatsapp://send?text=${Uri.encodeComponent(texte)}')) || await _ouvrir(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}'));

/// L application de messages, le texte deja ecrit.
Future<bool> partagerSms(String texte) => _ouvrir(Uri.parse('smsto:?body=${Uri.encodeComponent(texte)}'));

/// La messagerie, l objet et le texte deja ecrits.
Future<bool> partagerEmail(String objet, String texte) => _ouvrir(Uri.parse('mailto:?subject=${Uri.encodeComponent(objet)}&body=${Uri.encodeComponent(texte)}'));

/// La feuille de partage d Android : la photo et le texte. Sans photo, le texte seul.
/// Si la photo ne passe pas, le texte part seul ; faux si la feuille n a pas pu s ouvrir.
Future<bool> partagerAilleurs(String texte, {String? photo, String? objet}) async {
  final fichiers = <XFile>[];
  if (photo != null) {
    try {
      // Une photo du serveur (deja gardee sur le telephone), ou un fichier du telephone.
      // Pas plus de 8 s : au-dela, le texte part seul plutot que de faire attendre.
      if (photo.startsWith('http')) {
        fichiers.add(XFile.fromData(await ImagesReseau.octets(photo).timeout(const Duration(seconds: 8)), mimeType: 'image/webp', name: 'discover.webp'));
      } else if (photo.startsWith('/') && File(photo).existsSync()) {
        fichiers.add(XFile(photo));
      }
    } catch (_) {}
  }
  if (fichiers.isNotEmpty) {
    try {
      await SharePlus.instance.share(ShareParams(text: texte, subject: objet, files: fichiers));
      return true;
    } catch (e) {
      debugPrint('Partage avec la photo impossible : $e');
    }
  }
  try {
    await SharePlus.instance.share(ShareParams(text: texte, subject: objet));
    return true;
  } catch (e) {
    debugPrint('Partage impossible : $e');
    return false;
  }
}
