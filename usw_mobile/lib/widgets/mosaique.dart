// La mosaique des publications (photos et reels), fidele a Pinterest : a
// plat, 5 px d ecart, la hauteur du vrai format ; dessous, qui l a prise et
// avec quel telephone. Sur la page d un lieu, les cartes entrent facon
// « Coulisses ».
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../donnees/modeles.dart';
import '../theme/jetons.dart';
import 'coulisses.dart';
import 'icone.dart';
import 'options.dart';
import 'photo.dart';
import 'verre.dart';
import '../outils/langue.dart';

/// Les colonnes : chaque carte va dans la plus courte, et sait de quel cote
/// elle est (pour arriver de son cote, sur la page d un lieu).
class MosaiquePublications extends StatelessWidget {
  const MosaiquePublications({super.key, required this.publications, required this.onTap, this.coulisses = false, this.titre});

  final List<Publication> publications;
  final ValueChanged<int> onTap;

  /// L entree « Coulisses » : seulement sur la page d un lieu (pile deliee).
  final bool coulisses;

  /// Ce qui s ecrit sous la photo n° i ; par defaut, son auteur.
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
      hauteurs[c] += 1 / (ratioDe(publications[i].photo));
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
                      child: CartePublication(publication: publication, coulisses: true, titre: titre?.call(i), onTap: () => onTap(i)),
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
  const CartePublication({super.key, required this.publication, required this.onTap, this.coulisses = false, this.titre});

  final Publication publication;
  final VoidCallback onTap;
  final bool coulisses;
  final String? titre;

  // Fidele a la mosaique de Pinterest : la photo a plat (sans ombre), 12 de
  // rayon, 5 px d ecart, pas de « ... ». Dessous, ce qui fait USW : qui a pris
  // la photo, et avec quel telephone.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Appuyable(
      semantique: publication.reel ? t('Reel de {auteur}', {'auteur': publication.auteur}) : t('Photo de {auteur}', {'auteur': publication.auteur}),
      onTap: onTap,
      // Les options (enregistrer, partager, signaler ; supprimer la mienne) : un appui long, comme Pinterest.
      onLongPress: () {
        HapticFeedback.mediumImpact();
        optionsPublication(context, publication, titre: titre);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: ratioDe(publication.photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coulisses ? CoulissesImage(child: Photo(publication.photo)) : Photo(publication.photo),
                  // Une video se lit sans le son, en boucle, sur sa couverture.
                  if (publication.video != null) VideoMuette(publication.videoApercu ?? publication.video!),
                  if (publication.reel) ...[
                    Positioned(top: 8, left: 8, child: _Pastille(texte: _duree(publication.dureeReel!))),
                    // Un reel : la carte montre sa couverture, la video s ouvre au toucher.
                    const Positioned(top: 8, right: 8, child: _Pastille(icone: 'reels')),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icone('telephone', taille: 13),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        publication.appareil,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Couleurs.discret),
                      ),
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

/// La duree d un reel ou son son coupe, sur la photo : une pastille sombre
/// et nette (pas de flou, il couterait a chaque image).
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
    decoration: BoxDecoration(color: Couleurs.hsl(229, 30, 8, 0.55), borderRadius: BorderRadius.circular(12)),
    child: texte != null
        ? Text(
            texte!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          )
        : Icone(icone!, taille: 15, couleur: Colors.white),
  );
}
