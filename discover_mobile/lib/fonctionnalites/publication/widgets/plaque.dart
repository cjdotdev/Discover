import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';

/// La plaque (reprise de usw_mobile) : le support des informations et des listes,
/// à plat comme les cartes des Paramètres du téléphone. Un fond plein un ton
/// au-dessus de la page, des coins ronds, ni bord, ni ombre. Le verre reste aux
/// boutons et à ce qui flotte.
class Plaque extends StatelessWidget {
  const Plaque({super.key, required this.child, this.rayon = 22, this.padding});

  final Widget child;
  final double rayon;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Couleurs.surface.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(rayon),
    ),
    child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
  );
}
