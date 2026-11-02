// La mosaïque des publications (photos et reels), fidèle à Pinterest : à
// plat, 5 px d'écart, la hauteur du vrai format ; dessous, qui l'a prise et
// avec quel téléphone. Sur la page d'un lieu, les cartes entrent façon
// « Coulisses ».
import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../donnees/demo.dart';
import 'coulisses.dart';
import 'jetons.dart';
import 'photo.dart';
import 'verre.dart';

/// Les colonnes : chaque carte va dans la plus courte, et sait de quel côté
/// elle est (pour arriver de son côté, sur la page d'un lieu).
class MosaiquePublications extends StatelessWidget {
  const MosaiquePublications({
    super.key,
    required this.publications,
    required this.onTap,
    this.coulisses = false,
    this.titre,
  });

  final List<Publication> publications;
  final ValueChanged<int> onTap;

  /// L'entrée « Coulisses » : seulement sur la page d'un lieu.
  final bool coulisses;

  /// Ce qui s'écrit sous la photo n° i ; par défaut, son auteur.
  final String Function(int)? titre;

  @override
  Widget build(BuildContext context) {
    final colonnes = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
    final hauteurs = List<double>.filled(colonnes, 0);
    final rangs = List.generate(colonnes, (_) => <(int, Publication)>[]);
    for (var i = 0; i < publications.length; i++) {
      var c = 0;
      for (var k = 1; k < colonnes; k++) {
        if (hauteurs[k] < hauteurs[c]) c = k;
      }
      rangs[c].add((i, publications[i]));
      hauteurs[c] += 1 / (ratiosPhotos[publications[i].photo] ?? 0.75);
    }
    int cote(int c) => colonnes == 3 ? c - 1 : (c == 0 ? -1 : 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < colonnes; c++) ...[
          if (c > 0) const SizedBox(width: 5),
          Expanded(
            child: Column(
              children: [
                for (final (i, publication) in rangs[c])
                  if (coulisses)
                    Coulisses(
                      cote: cote(c),
                      child: CartePublication(
                        publication: publication,
                        coulisses: true,
                        titre: titre?.call(i),
                        onTap: () => onTap(i),
                      ),
                    )
                  else
                    CartePublication(publication: publication, titre: titre?.call(i), onTap: () => onTap(i)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class CartePublication extends StatelessWidget {
  const CartePublication({
    super.key,
    required this.publication,
    required this.onTap,
    this.coulisses = false,
    this.titre,
  });

  final Publication publication;
  final VoidCallback onTap;
  final bool coulisses;
  final String? titre;

  // Fidèle à la mosaïque de Pinterest : la photo à plat (sans ombre), 12 de
  // rayon, 5 px d'écart. Dessous : qui a pris la photo, et avec quel téléphone.
  // Dans usw_mobile, un appui long ouvrait partager, télécharger, enregistrer et
  // signaler (E08, E09, E10, E22) : hors du MVP (repartition.md), donc retiré ici.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Appuyable(
      semantique: '${publication.reel ? 'Reel' : 'Photo'} de ${publication.auteur}',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: ratiosPhotos[publication.photo] ?? 0.75,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coulisses ? CoulissesImage(child: Photo(publication.photo)) : Photo(publication.photo),
                  if (publication.reel) ...[
                    Positioned(top: 8, left: 8, child: _Pastille(texte: _duree(publication.dureeReel!))),
                    const Positioned(top: 8, right: 8, child: _Pastille(icone: 'muet')),
                  ],
                  Positioned(left: 8, bottom: 8, child: BadgeCapture(verifie: publication.verifiee, seul: true)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 6, 3, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre ?? publication.auteur,
                  overflow: TextOverflow.ellipsis,
                  style: Textes.petit.copyWith(color: Couleurs.texte, fontWeight: FontWeight.w600, height: 1.25),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icone('telephone', taille: 13),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(publication.appareil, overflow: TextOverflow.ellipsis, style: Textes.petit),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  static String _duree(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// La durée d'un reel ou son son coupé, sur la photo : une pastille sombre et nette.
class _Pastille extends StatelessWidget {
  const _Pastille({this.texte, this.icone});

  final String? texte;
  final String? icone;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    constraints: const BoxConstraints(minWidth: 24),
    padding: EdgeInsets.symmetric(horizontal: texte == null ? 0 : 8),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: Teintes.hsl(229, 30, 8, 0.55), borderRadius: BorderRadius.circular(12)),
    child: texte != null
        ? Text(
            texte!,
            style: Textes.petit.copyWith(fontWeight: FontWeight.w600, color: Colors.white, height: 1),
          )
        : Icone(icone!, taille: 15, couleur: Colors.white),
  );
}
