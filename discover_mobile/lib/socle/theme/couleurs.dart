import 'package:flutter/painting.dart';

// Les couleurs de la maquette (styles/tokens.css), rangées au même endroit.
// Un rôle par couleur : l'océan pour ce qui se touche, la limonade pour ce qui est vérifié.
abstract final class Couleurs {
  static const fond = Color(0xFFE3E6F2);
  static const surface = Color(0xFFFFFFFF);
  static const secondaire = Color(0xFFF4F4F6);
  static const bord = Color(0xFFE4E4E7);
  static const texte = Color(0xFF121212);
  static const discret = Color(0xFF65758B);
  static const ocean = Color(0xFF1D46FC);
  static const limonade = Color(0xFFCDF22C);
  static const encreLimonade = Color(0xFF31390E);
  static const erreur = Color(0xFFEF4343);
  static const succes = Color(0xFF2E9E53);
  static const photoVide = Color(0xFFCCD0E0);
}
