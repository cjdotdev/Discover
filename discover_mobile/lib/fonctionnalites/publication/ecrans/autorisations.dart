// E32 Autorisations (repris de usw_mobile) : une seule fois, la position, le modèle
// du téléphone, la caméra et le micro. Elles donnent le badge « Capture vérifiée ».
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart' show Lien;
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/page_formulaire.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/envois.dart';
import '../widgets/plaque.dart';

/// E32 Autorisations. Voir repartition.md.
class EcranAutorisations extends StatefulWidget {
  const EcranAutorisations({super.key});

  @override
  State<EcranAutorisations> createState() => _EcranAutorisationsState();
}

class _EcranAutorisationsState extends State<EcranAutorisations> {
  final _choix = [true, true, true];

  @override
  Widget build(BuildContext context) => PageFormulaire(
    titre: 'Une seule fois',
    entete: const Verre(
      rayon: 44,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Center(child: Icone('camera', taille: 40, couleur: Couleurs.texte)),
      ),
    ),
    sousTitre: const Text(
      "Les photos se prennent avec l'appareil photo de votre téléphone, avec tous ses modes. "
      'Discover y ajoute la position et le modèle : elles auront le badge Capture vérifiée.',
    ),
    pied: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BoutonVerre(
          texte: 'Autoriser',
          plein: true,
          onTap: () {
            Brouillon.instance.autorise = true;
            context.pushReplacement(Routes.details);
          },
        ),
        const SizedBox(height: 8),
        Lien('Plus tard', discret: true, onTap: () => context.pop()),
      ],
    ),
    children: [
      for (final (i, icone, titre, texte) in const [
        (0, 'cible', 'Position', 'Inscrite à chaque photo et chaque reel.'),
        (1, 'telephone', 'Modèle du téléphone', 'Tecno Camon 50 Pro, lu sur l’appareil.'),
        (2, 'micro', 'Caméra et micro', 'Pour tourner les reels dans Discover.'),
      ]) ...[
        Plaque(
          rayon: 20,
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Icone(icone, taille: 24, couleur: Couleurs.texte),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: Textes.libelle),
                    Text(texte, style: Textes.petit),
                  ],
                ),
              ),
              Switch(
                value: _choix[i],
                activeTrackColor: Couleurs.ocean,
                onChanged: (v) => setState(() => _choix[i] = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}
