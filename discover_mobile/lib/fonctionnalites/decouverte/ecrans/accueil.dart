// E03 Accueil (repris de usw_mobile) : une mosaïque de piles de photos par lieu,
// qui tournent ; toucher une pile ouvre le lieu (E33). Épuré : ni flux ni filtres
// en haut, les filtres sont dans la recherche (E31).
// À brancher : GET flux/decouverte (voir repartition.md, section Backend).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../donnees/demo.dart';
import '../widgets/jetons.dart';
import '../widgets/mouvement.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';

/// E03 Accueil. Voir repartition.md.
class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(largeur);
    final colonnes = largeur >= 600 ? 3 : 2;
    // Bord à bord : les photos passent sous la barre d'état. Seul l'en-tête réserve sa place.
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // L'en-tête se range quand on descend dans le flux et revient dès
          // qu'on remonte (0,45 s, courbe interface).
          SliverFloatingHeader(
            snapMode: FloatingHeaderSnapMode.scroll,
            animationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 450),
              curve: Courbes.interface,
              reverseDuration: Duration(milliseconds: 450),
              reverseCurve: Courbes.interface,
            ),
            // Pas de bloc plein : un simple dégradé du fond vers le transparent.
            // Quand l'en-tête revient sur le flux, les photos glissent dessous.
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Couleurs.fond.withValues(alpha: 0.94),
                    Couleurs.fond.withValues(alpha: 0.78),
                    Couleurs.fond.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(marge, haut + 6, marge, 22),
                child: Row(
                  children: [
                    const Logo(taille: 30),
                    const SizedBox(width: 8),
                    Text('Discover', style: Textes.sousTitre.copyWith(fontSize: 24, letterSpacing: -0.9)),
                    const Spacer(),
                    RondVerre(
                      icone: 'loupe',
                      semantique: 'Rechercher',
                      surPhoto: true,
                      onTap: () => context.push(Routes.recherche),
                    ),
                    const SizedBox(width: 6),
                    RondVerre(
                      icone: 'cloche',
                      semantique: 'Notifications',
                      point: true,
                      surPhoto: true,
                      onTap: () => context.push(Routes.notifications),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(marge, 0, marge, hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverToBoxAdapter(
              child: _Mosaique(lieux: lieuxDemo, colonnes: colonnes),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mosaique extends StatelessWidget {
  const _Mosaique({required this.lieux, required this.colonnes});

  final List<Lieu> lieux;
  final int colonnes;

  @override
  Widget build(BuildContext context) {
    final hauteurs = List<double>.filled(colonnes, 0);
    final rangs = List.generate(colonnes, (_) => <(int, Lieu)>[]);
    for (var i = 0; i < lieux.length; i++) {
      var c = 0;
      for (var k = 1; k < colonnes; k++) {
        if (hauteurs[k] < hauteurs[c]) c = k;
      }
      rangs[c].add((i, lieux[i]));
      hauteurs[c] += 1 / lieux[i].ratio + 0.25;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < colonnes; c++) ...[
          if (c > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (final (i, lieu) in rangs[c])
                  Monte(
                    delai: Duration(milliseconds: 250 + 70 * i),
                    child: _PileLieu(lieu: lieu, rang: i),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PileLieu extends StatelessWidget {
  const _PileLieu({required this.lieu, required this.rang});

  final Lieu lieu;
  final int rang;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Appuyable(
      semantique: '${lieu.nom}, ${lieu.nombre} photos',
      onTap: () => context.push(Routes.lieu(lieu.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: lieu.ratio,
            child: Pile(
              photos: lieu.photos,
              decalage: Duration(milliseconds: 500 * rang),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lieu.nom, style: Textes.libelle.copyWith(fontSize: 13.5, height: 1.25)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icone('camera', taille: 14, couleur: Couleurs.discret),
                        const SizedBox(width: 3),
                        Text('${lieu.nombre} photos', style: Textes.petit.copyWith(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icone('plus-points', taille: 20, couleur: Couleurs.discret),
            ],
          ),
        ],
      ),
    ),
  );
}
