import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import 'jetons.dart';

/// Des onglets de texte : l'actif à l'encre, souligné d'un trait qui glisse.
class OngletsTexte extends StatelessWidget {
  const OngletsTexte({super.key, required this.noms, required this.actif, required this.onChange});

  final List<String> noms;
  final int actif;
  final ValueChanged<int> onChange;

  // Trop larges pour l'écran (texte agrandi), les onglets se resserrent.
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < noms.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          GestureDetector(
            onTap: () => onChange(i),
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              selected: i == actif,
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: Durees.interface,
                      // On part du style hérité : il porte la police Wura Mi du thème.
                      style: DefaultTextStyle.of(context).style.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: i == actif ? Couleurs.texte : Couleurs.discret,
                      ),
                      child: Text(noms[i]),
                    ),
                    const SizedBox(height: 6),
                    // Le ressort dépasse sa cible : en se rétractant, le trait passerait sous zéro.
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: i == actif ? 34 : 0),
                      duration: const Duration(milliseconds: 420),
                      curve: CourbesPlus.ressort,
                      builder: (context, largeur, _) => Container(
                        height: 3,
                        width: largeur.clamp(0, double.infinity),
                        decoration: BoxDecoration(color: Couleurs.texte, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
