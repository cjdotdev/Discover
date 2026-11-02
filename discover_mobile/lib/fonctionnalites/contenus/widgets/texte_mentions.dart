import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';

/// Un texte où les @mentions et les moments (0:12) ressortent (repris de usw_mobile).
class TexteMentions extends StatelessWidget {
  const TexteMentions(this.texte, {super.key, this.couleur});

  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final morceaux = <TextSpan>[];
    texte.splitMapJoin(
      RegExp(r'@[\w.]+|\b\d:\d\d\b'),
      onMatch: (m) {
        morceaux.add(
          TextSpan(
            text: m[0],
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        return '';
      },
      onNonMatch: (t) {
        morceaux.add(TextSpan(text: t));
        return '';
      },
    );
    return Text.rich(
      TextSpan(children: morceaux),
      style: Textes.corps.copyWith(fontSize: 14.5, color: couleur ?? Couleurs.texte),
    );
  }
}
