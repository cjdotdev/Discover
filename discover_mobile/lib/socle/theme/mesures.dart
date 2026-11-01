import 'package:flutter/animation.dart';

// Les espacements et les arrondis de la maquette.
abstract final class Mesures {
  static const marge = 16.0;
  static const margeTablette = 28.0;
  static const largeurFormulaire = 480.0;
  static const hautBouton = 50.0;
  static const hautChamp = 54.0;
  static const rayonBouton = 14.0;
  static const rayonCarte = 18.0;
  static const rayonPhoto = 26.0;

  /// La marge de page : plus large sur une tablette.
  static double margeDe(double largeur) => largeur >= 600 ? margeTablette : marge;
}

// Les durées et les courbes de la charte du mouvement (MOUVEMENT.md).
abstract final class Durees {
  static const appui = Duration(milliseconds: 120);
  static const interface = Duration(milliseconds: 300);
  static const ecran = Duration(milliseconds: 650);
}

abstract final class Courbes {
  static const signature = Cubic(0.35, 0, 0, 1);
  static const interface = Cubic(0.4, 0, 0.1, 1);
}
