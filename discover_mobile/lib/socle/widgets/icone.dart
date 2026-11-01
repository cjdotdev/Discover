import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/couleurs.dart';

/// Une icône du pack (assets/icones) : `Icone('loupe')`. Sa couleur suit le texte autour.
class Icone extends StatelessWidget {
  const Icone(this.nom, {super.key, this.taille = 24, this.couleur});

  final String nom;
  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final teinte = couleur ?? DefaultTextStyle.of(context).style.color ?? Couleurs.texte;
    return SvgPicture.asset(
      'assets/icones/$nom.svg',
      width: taille,
      height: taille,
      theme: SvgTheme(currentColor: teinte),
    );
  }
}

/// Le logo de l'application.
class Logo extends StatelessWidget {
  const Logo({super.key, this.taille = 56});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/logo/usw.svg', width: taille, height: taille, semanticsLabel: 'Discover');
  }
}
