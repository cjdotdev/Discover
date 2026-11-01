import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';

/// La liste des règles du mot de passe : chacune se coche quand elle est remplie.
class Criteres extends StatelessWidget {
  const Criteres({super.key, required this.criteres});

  final List<(String, bool)> criteres;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (texte, rempli) in criteres)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Durees.interface,
                  width: 18,
                  height: 18,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rempli ? Couleurs.succes : Couleurs.texte.withValues(alpha: 0.08),
                  ),
                  child: Icone('coche', taille: 14, couleur: rempli ? Colors.white : Colors.transparent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(texte, style: Textes.petit.copyWith(color: rempli ? Couleurs.texte : Couleurs.discret)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
