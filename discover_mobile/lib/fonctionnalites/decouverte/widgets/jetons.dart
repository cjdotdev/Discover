// Les jetons de la maquette dont la découverte a besoin et que le socle n'a pas encore
// (repris de usw_mobile, theme/jetons.dart). À verser dans le socle avec Siméon.
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../../socle/theme/couleurs.dart';

Color _hsl(double h, double s, double l, [double a = 1]) => HSLColor.fromAHSL(a, h, s / 100, l / 100).toColor();

/// Les teintes du verre, des ombres et des traits.
abstract final class Teintes {
  static final voile = _hsl(229, 30, 30, 0.14);
  static final ombre = _hsl(229, 50, 20, 0.36);

  /// Les séparateurs des listes.
  static final filet = _hsl(229, 30, 30, 0.09);

  /// Les traits discrets : poignée, interrupteur éteint.
  static final trait = _hsl(229, 20, 40, 0.28);

  /// Ce qui s'écrit sur un fond à l'encre (pastille choisie).
  static const surEncre = Couleurs.surface;
  static final ombreOcean = _hsl(229, 97, 45, 0.65);
  static final oceanClair = _hsl(229, 97, 60, 0.8);
  static final oceanFonce = _hsl(229, 97, 52, 0.84);

  static Color hsl(double h, double s, double l, [double a = 1]) => _hsl(h, s, l, a);
}

// Les courbes et durées de MOUVEMENT.md absentes du socle.
abstract final class CourbesPlus {
  /// L'appui sur le verre, une coche, un cœur.
  static const ressort = Cubic(0.34, 1.56, 0.64, 1);

  /// Les piles de photos qui tournent.
  static const pile = Cubic(0.22, 1, 0.36, 1);
}

abstract final class DureesPlus {
  static const entree = Duration(milliseconds: 900);
}

/// La hauteur de la barre d'onglets flottante (socle/navigation/coquille_onglets.dart).
const hautOnglets = 64.0;
