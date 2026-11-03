import 'dart:io';

import 'package:flutter/material.dart';

import '../outils/images_reseau.dart';

import '../donnees/session.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';

/// Les initiales sur une teinte tiree du nom : chaque membre garde la sienne.
/// Avec une photo (un fichier du telephone), la photo, ronde.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nom, this.taille = 46, this.photo});

  final String nom;
  final double taille;

  /// Le chemin d une photo sur le telephone, ou son adresse sur le serveur.
  final String? photo;

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return ClipOval(
        child: Image(
          image: photo!.startsWith('http') ? ImageReseau(photo!) : FileImage(File(photo!)) as ImageProvider,
          width: taille,
          height: taille,
          fit: BoxFit.cover,
          // Pendant le chargement, les initiales : jamais un rond vide (noir sur le fond sombre).
          frameBuilder: (_, image, frame, deja) => deja || frame != null ? image : Avatar(nom: nom, taille: taille),
          errorBuilder: (_, _, _) => Avatar(nom: nom, taille: taille),
        ),
      );
    }
    final initiales = nom.split(RegExp(r'\s+')).where((m) => m.isNotEmpty).take(2).map((m) => m[0].toUpperCase()).join();
    final teinte = (nom.codeUnits.fold<int>(0, (a, b) => a + b) * 47) % 360;
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Couleurs.hsl(teinte.toDouble(), 55, 48), shape: BoxShape.circle),
      child: Text(
        initiales.isEmpty ? 'U' : initiales,
        style: TextStyle(fontSize: taille * 0.34, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// L avatar du membre connecte : sa photo des qu il en a choisi une, partout.
class AvatarMoi extends StatelessWidget {
  const AvatarMoi({super.key, this.taille = 46, this.nom});

  final double taille;

  /// Le nom a montrer en initiales, s il change avant d etre enregistre.
  final String? nom;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Session.instance,
    builder: (context, _) {
      final s = Session.instance;
      // La photo choisie sur ce telephone, sinon celle du serveur (apres une reinstallation).
      return Avatar(nom: nom ?? (s.nomAffiche), taille: taille, photo: s.photo ?? s.avatar);
    },
  );
}

/// La photo de profil, touchee : elle grandit depuis son rond jusqu au milieu
/// de l ecran, sur un voile sombre ; un toucher la referme, comme WhatsApp.
/// Sans photo (des initiales), rien ne s ouvre.
class AvatarAgrandissable extends StatelessWidget {
  const AvatarAgrandissable({super.key, required this.nom, required this.photo, this.taille = 104});

  final String nom;
  final String? photo;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final rond = Hero(
      tag: 'avatar:$nom:$photo',
      child: Avatar(nom: nom, taille: taille, photo: photo),
    );
    final p = photo;
    if (p == null) return rond;
    return Semantics(
      // Un bouton a part, que le lecteur d ecran ne fond pas dans l en-tete du profil.
      container: true,
      button: true,
      label: t('Agrandir la photo de {nom}', {'nom': nom}),
      excludeSemantics: true,
      child: GestureDetector(onTap: () => _ouvrir(context, p), child: rond),
    );
  }

  void _ouvrir(BuildContext context, String p) => Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: t('Fermer'),
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: Durees.interface,
      reverseTransitionDuration: Durees.interface,
      pageBuilder: (context, _, _) {
        final cote = (MediaQuery.sizeOf(context).shortestSide - 48).clamp(160.0, 360.0);
        return Semantics(
          button: true,
          label: t('Fermer la photo'),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Hero(
                tag: 'avatar:$nom:$photo',
                child: Avatar(nom: nom, taille: cote, photo: p),
              ),
            ),
          ),
        );
      },
    ),
  );
}
