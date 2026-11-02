// E12 Créer (repris de la feuille « Créer » de usw_mobile, ici en page d'onglet) :
// prendre une photo avec l'appareil du téléphone, tourner un reel, importer de la
// galerie, et le rappel « pas d'IA ». Simulé : l'appareil photo et la galerie
// se brancheront avec image_picker.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/widgets/jetons.dart';
import '../donnees/envois.dart';
import '../widgets/plaque.dart';

/// E12 Créer. Voir repartition.md.
class EcranCreer extends StatelessWidget {
  const EcranCreer({super.key});

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final brouillon = Brouillon.instance;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, 24, marge, hautOnglets + 40),
          children: [
            Semantics(header: true, child: const Text('Créer', style: Textes.titre)),
            const SizedBox(height: 18),
            _OptionCreer(
              icone: 'camera',
              titre: 'Prendre une photo',
              texte: "Avec l'appareil photo du téléphone, tous ses modes",
              onTap: () {
                brouillon.declaree = false;
                context.push(brouillon.autorise ? Routes.details : Routes.autorisations);
              },
            ),
            // La caméra des reels (E27) est hors du MVP : un reel se publie par import.
            _OptionCreer(
              icone: 'reels',
              titre: 'Tourner un reel',
              texte: '15, 30 ou 60 secondes, en plusieurs séquences',
              onTap: () => bulle(context, 'Pour le moment, importez votre reel depuis la galerie.'),
            ),
            _OptionCreer(
              icone: 'image',
              titre: 'Importer de la galerie',
              texte: 'Une photo ou une vidéo déjà prise, même ancienne',
              onTap: () {
                brouillon.declaree = true;
                context.push(Routes.completerCapture);
              },
            ),
            const SizedBox(height: 18),
            Plaque(
              rayon: 20,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icone('bouclier', taille: 22, couleur: Couleurs.texte),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: "Discover n'accepte que des photos et des vidéos réelles : les images générées par IA sont refusées. ",
                          ),
                          TextSpan(
                            text: 'Les règles',
                            style: Textes.libelle.copyWith(decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                      style: Textes.discret,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCreer extends StatelessWidget {
  const _OptionCreer({required this.icone, required this.titre, required this.texte, required this.onTap});

  final String icone;
  final String titre;
  final String texte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Couleurs.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icone(icone, taille: 25, couleur: Couleurs.texte),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: Textes.libelle.copyWith(fontSize: 16)),
                Text(texte, style: Textes.petit),
              ],
            ),
          ),
          const Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
        ],
      ),
    ),
  );
}
