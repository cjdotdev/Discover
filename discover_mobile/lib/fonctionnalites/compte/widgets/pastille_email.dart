import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/icone.dart';

/// Rappelle l'adresse saisie, avec « Changer » pour revenir à l'entrée.
class PastilleEmail extends StatelessWidget {
  const PastilleEmail({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icone('enveloppe', taille: 17, couleur: Couleurs.discret),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              email,
              overflow: TextOverflow.ellipsis,
              style: Textes.petit.copyWith(color: Couleurs.texte),
            ),
          ),
          const SizedBox(width: 10),
          Lien('Changer', onTap: () => context.pop()),
        ],
      ),
    );
  }
}
