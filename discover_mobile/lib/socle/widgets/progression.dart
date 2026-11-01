import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/mesures.dart';

/// Les traits en haut des pages à étapes : un trait par étape, plein quand elle est passée.
class Progression extends StatelessWidget {
  const Progression({super.key, required this.etape, required this.total});

  /// L'étape en cours, à partir de 0.
  final int etape;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: Durees.interface,
              height: 3,
              decoration: BoxDecoration(
                color: i <= etape ? Couleurs.texte : Couleurs.texte.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
