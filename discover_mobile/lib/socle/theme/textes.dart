import 'package:flutter/painting.dart';

import 'couleurs.dart';

// Les styles de texte de la maquette. Un écran n'écrit jamais une taille à la main.
abstract final class Textes {
  static const titre = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.08,
    color: Couleurs.texte,
  );
  static const sousTitre = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.15, color: Couleurs.texte);
  static const corps = TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texte);
  static const discret = TextStyle(fontSize: 15.5, height: 1.45, color: Couleurs.discret);
  static const petit = TextStyle(fontSize: 13, height: 1.45, color: Couleurs.discret);
  static const libelle = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Couleurs.texte);
  static const bouton = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1);
  static const lien = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Couleurs.ocean);
}
