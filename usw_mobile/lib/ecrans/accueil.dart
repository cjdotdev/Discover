// E03 Accueil : une mosaique de piles de photos par lieu, qui tournent ;
// toucher une pile ouvre le lieu (E33). Epure a la demande de l utilisateur :
// ni flux ni filtres en haut, les filtres sont dans la recherche (E31).
// Les lieux viennent de GET /api/v1/flux/decouverte (donnees/catalogue.dart) :
// la page suivante arrive quand on approche du bas, et tirer vers le bas en
// haut de la page actualise, comme sur iOS.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show FloatingHeaderSnapConfiguration;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'etats.dart';
import 'gerer/gerer.dart';
import 'visionneuse.dart';

import '../donnees/catalogue.dart';
import '../donnees/communaute.dart';
import '../donnees/lieux_enregistres.dart';
import '../donnees/mes_publications.dart';
import '../outils/chemins.dart';
import '../outils/langue.dart';
import '../donnees/modeles.dart';
import '../theme/jetons.dart';
import '../widgets/icone.dart';
import '../widgets/mouvement.dart';
import '../widgets/options.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';

class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(largeur);
    final colonnes = largeur >= 600 ? 3 : 2;
    // Bord a bord : les photos passent sous la barre d etat, comme la
    // mosaique de l entree. Seul l en-tete reserve sa place.
    return Scaffold(
      // Le bas approche : la page suivante de Decouverte.
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 900) Catalogue.instance.suite();
          return false;
        },
        child: CustomScrollView(
          slivers: [
            // Tirer vers le bas, tout en haut : l accueil se refait avec ce qui vient d etre publie.
            // Tirer : le logo apparait et tourne avec le doigt ; pendant l actualisation, il tourne seul.
            CupertinoSliverRefreshControl(
              onRefresh: Catalogue.instance.rafraichir,
              builder: (context, etat, tire, seuil, _) {
                final t = seuil <= 0 ? 0.0 : (tire / seuil).clamp(0.0, 1.0);
                final tourne = etat == RefreshIndicatorMode.armed || etat == RefreshIndicatorMode.refresh;
                return Center(
                  child: Opacity(
                    opacity: tourne ? 1 : t,
                    child: tourne ? const LogoQuiTourne(taille: 28) : Transform.rotate(angle: -t * 2 * math.pi, child: const LogoUsw(taille: 28)),
                  ),
                );
              },
            ),
            // L en-tete se range quand on descend dans le flux et revient des
            // qu on remonte. Il suit le doigt, s efface en glissant (plus de bloc
            // dur), puis finit son geste en douceur. Les filtres sont dans la
            // recherche : l accueil ne montre que les lieux.
            SliverPersistentHeader(
              floating: true,
              delegate: _EnTete(
                hauteur: haut + 72,
                vsync: this,
                // Pas de bloc plein : un simple degrade du fond vers le transparent,
                // sans flou. Quand l en-tete revient sur le flux, les photos
                // glissent dessous et s effacent en douceur sous le logo.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Couleurs.fond.withValues(alpha: 0.94), Couleurs.fond.withValues(alpha: 0.78), Couleurs.fond.withValues(alpha: 0)],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(marge, haut + 6, marge, 22),
                    child: Row(
                      children: [
                        GestureDetector(
                          onLongPress: () => ouvrirGerer(context),
                          child: const Row(
                            children: [
                              LogoUsw(taille: 30),
                              SizedBox(width: 8),
                              Text('Discover', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.9)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        RondVerre(icone: 'loupe', semantique: t('Rechercher'), surPhoto: true, onTap: () => context.push(ici(context, 'recherche'))),
                        const SizedBox(width: 6),
                        ListenableBuilder(
                          listenable: Communaute.instance,
                          builder: (context, _) =>
                              RondVerre(icone: 'cloche', semantique: t('Notifications'), point: Communaute.instance.nonLues > 0, surPhoto: true, onTap: () => context.push('/notifications')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(marge, 0, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverToBoxAdapter(
                // Ce que le membre vient de publier passe en tete, une pile par publication.
                child: ListenableBuilder(
                  listenable: Listenable.merge([MesPublications.instance, Catalogue.instance]),
                  builder: (context, _) {
                    // Ma publication, tant que le serveur ne la montre pas lui-meme dans une pile :
                    // une fois en ligne, c est sa pile (et son lieu) qui la montre, pas deux fois.
                    // Jamais deux fois la meme publication. Vers un lieu deja a l accueil, ma
                    // publication va dans sa pile, devant, des l envoi (pas une pile a cote) ;
                    // vers un lieu tout neuf, une pile a elle, jusqu a ce que le serveur montre
                    // celle du lieu. Le lieu d une publication en ligne est demande au serveur.
                    final serveur = Catalogue.instance.lieux;
                    final ids = {for (final l in serveur) l.id};
                    final devant = <String, List<String>>{};
                    final seules = <Lieu>[];
                    for (final p in MesPublications.instance.pourAccueil) {
                      final contenu = p.contenu;
                      if (contenu != null) Catalogue.instance.connaitrePublication(contenu);
                      // Choisi dans les suggestions de Google, il n a pas encore l identifiant de
                      // Discover : son nom suffit a trouver sa pile.
                      final nom = p.lieu.split(',').first.trim().toLowerCase();
                      final lieu =
                          (contenu == null ? null : Catalogue.instance.publication(contenu)?.lieu) ??
                          (ids.contains(p.lieuId) ? p.lieuId : null) ??
                          serveur.where((l) => l.situe && nom.isNotEmpty && l.nom.trim().toLowerCase() == nom).firstOrNull?.id;
                      if (lieu != null && ids.contains(lieu)) {
                        if (contenu == null || !Catalogue.instance.dansLaPile(lieu, contenu)) (devant[lieu] ??= []).add(p.photo);
                      } else if (contenu == null || !Catalogue.instance.aLAccueil(contenu)) {
                        seules.add(_pileDe(p));
                      }
                    }
                    final lieux = [...seules, for (final l in serveur) devant[l.id] == null ? l : l.avecDevant(devant[l.id]!)];
                    if (lieux.isNotEmpty) return _Mosaique(lieux: lieux, colonnes: colonnes);
                    return SizedBox(height: MediaQuery.sizeOf(context).height * 0.6, child: const _Vide());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L en-tete de l accueil, qui suit le doigt : en se rangeant il monte et
/// s efface ; lache a mi-chemin, il finit son geste sur une courbe douce.
class _EnTete extends SliverPersistentHeaderDelegate {
  _EnTete({required this.hauteur, required this.vsync, required this.child});

  final double hauteur;
  final Widget child;

  @override
  final TickerProvider vsync;

  @override
  double get minExtent => 0;

  @override
  double get maxExtent => hauteur;

  @override
  FloatingHeaderSnapConfiguration get snapConfiguration => FloatingHeaderSnapConfiguration(curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 380));

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = (shrinkOffset / hauteur).clamp(0.0, 1.0);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        minHeight: hauteur,
        maxHeight: hauteur,
        child: Opacity(opacity: 1 - Curves.easeIn.transform(range), child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(_EnTete ancien) => ancien.hauteur != hauteur || ancien.child != child;
}

/// L accueil sans lieu : le premier chargement, pas de reseau, ou rien encore.
class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    final c = Catalogue.instance;
    if (c.horsLigne) {
      return EtatVide(icone: 'hors-ligne', titre: t('Aucune connexion'), texte: t('Les lieux s’afficheront dès que le réseau sera rétabli.'), action: t('Réessayer'), onAction: c.rafraichir);
    }
    if (!c.duServeur) {
      return Center(child: const LogoQuiTourne(taille: 34));
    }
    // Des lieux masques (« Voir moins ») : on dit ou les retrouver.
    if (c.masques.isNotEmpty) {
      return EtatVide(
        icone: 'oeil',
        titre: t('Rien à afficher'),
        texte: t('Vous avez masqué des lieux. Pour les réafficher, ouvrez Réglages, puis Lieux masqués.'),
        action: t('Ouvrir les réglages'),
        onAction: () => context.push('/profil/reglages'),
      );
    }
    return EtatVide(icone: 'image', titre: t('Rien à afficher'), texte: t('Tirez vers le bas pour actualiser.'));
  }
}

/// Une de mes publications, en pile a l accueil : sa photo (pour une video, sa
/// couverture) et le nom de son lieu.
Lieu _pileDe(MaPublication p) => Lieu(
  id: 'mien-${p.date.millisecondsSinceEpoch}',
  nom: p.lieu.isEmpty ? t('Ma publication') : p.lieu.split(',').first,
  region: p.lieu,
  photos: [p.photo],
  nombre: 1,
  ratio: p.ratio.clamp(0.6, 1.0),
  type: '',
  latitude: p.latitude ?? 0,
  longitude: p.longitude ?? 0,
);

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

  // Ma publication (une pile a moi) : la partager, la supprimer ; un lieu : ses options.
  void _options(BuildContext context) {
    final mienne = MesPublications.instance.pourAccueil.where((p) => 'mien-${p.date.millisecondsSinceEpoch}' == lieu.id).firstOrNull;
    mienne == null ? optionsLieu(context, lieu) : optionsMaPublication(context, mienne);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Appuyable(
      semantique: '${lieu.nom}, ${nombrePublications(lieu.nombre)}',
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _options(context);
      },
      onTap: () {
        // Ma publication ouvre sa page des qu elle est en ligne (sinon en grand, la
        // video se lit) ; un lieu ouvre sa page.
        final mienne = MesPublications.instance.pourAccueil.where((p) => 'mien-${p.date.millisecondsSinceEpoch}' == lieu.id).firstOrNull;
        if (mienne == null) {
          context.push(ici(context, 'lieu/${lieu.id}'));
        } else if (mienne.contenu != null) {
          context.push(ici(context, 'lieu/${Catalogue.instance.publication(mienne.contenu!)?.lieu ?? '_'}/photo/${mienne.contenu}'));
        } else if (mienne.video != null) {
          ouvrirLecture(context, mienne.video!, affiche: mienne.photo);
        } else {
          ouvrirVisionneuse(context, mienne.photo);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: lieu.ratio,
            child: Pile(photos: lieu.photos),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lieu.nom, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icone('camera', taille: 14, couleur: Couleurs.discret),
                        const SizedBox(width: 3),
                        // Une colonne etroite (petit telephone, grande police) : le texte se coupe proprement.
                        Flexible(
                          child: Text(
                            lieu.id.startsWith('mien-') ? t('Votre publication') : nombrePublications(lieu.nombre),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Couleurs.discret),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Les « ... » de Pinterest : une cible large, sans ouvrir la pile.
              Appuyable(
                semantique: t('Plus d’options'),
                onTap: () => _options(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 0, 6),
                  child: Icone('plus-points', taille: 20, couleur: Couleurs.discret),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
