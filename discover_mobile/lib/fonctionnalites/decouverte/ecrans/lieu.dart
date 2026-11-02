// E33 Lieu (repris de usw_mobile) : la pile déliée. Toucher une pile de l'accueil
// ouvre son lieu : toutes ses photos et ses reels en mosaïque. Les cartes entrent
// façon « Coulisses » en suivant le défilement. Un reel se reconnaît à sa durée.
// À brancher : GET lieux/{lieu} et lieux/{lieu}/contenus.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../donnees/demo.dart';
import '../widgets/jetons.dart';
import '../widgets/mosaique.dart';
import '../widgets/mouvement.dart';
import '../widgets/verre.dart';

/// E33 Lieu. Voir repartition.md.
class EcranLieu extends StatelessWidget {
  const EcranLieu({super.key, required this.id});

  final String id;

  // « Y aller » ouvrait l'itinéraire dans Maps avec le paquet url_launcher, absent
  // de pubspec.yaml (le socle). Mis de côté pour le moment :
  //
  // Future<void> _yAller(BuildContext context, Lieu lieu) async {
  //   final itineraire = Uri.parse(
  //     'https://www.google.com/maps/dir/?api=1&destination=${lieu.latitude},${lieu.longitude}',
  //   );
  //   final ouvert = await launchUrl(itineraire, mode: LaunchMode.externalApplication);
  //   if (!ouvert && context.mounted) bulle(context, "Maps n'a pas pu s'ouvrir.");
  // }

  @override
  Widget build(BuildContext context) {
    final lieu = lieuxDemo.where((l) => l.id == id).firstOrNull;
    if (lieu == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
        body: const EtatMessage(icone: 'lieu', titre: 'Lieu introuvable', texte: "Ce lieu n'existe plus."),
      );
    }
    final largeur = MediaQuery.sizeOf(context).width;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(largeur);
    final publications = publicationsDe(lieu);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Comme à l'accueil : l'en-tête se range quand on descend et revient
          // dès qu'on remonte ; les photos passent sous la barre d'état.
          SliverFloatingHeader(
            snapMode: FloatingHeaderSnapMode.scroll,
            animationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 450),
              curve: Courbes.interface,
              reverseDuration: Duration(milliseconds: 450),
              reverseCurve: Courbes.interface,
            ),
            child: ColoredBox(
              color: Couleurs.fond,
              child: Padding(
                padding: EdgeInsets.fromLTRB(marge, haut + 6, marge, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RondVerre(
                          icone: 'retour',
                          semantique: 'Retour',
                          onTap: () => context.canPop() ? context.pop() : context.go(Routes.accueil),
                        ),
                        const Spacer(),
                        RondVerre(
                          icone: 'enregistrer',
                          semantique: 'Enregistrer le lieu',
                          onTap: () => bulle(context, 'Lieu enregistré dans vos collections.'),
                        ),
                        const SizedBox(width: 6),
                        // Le partage (E10) est hors du MVP : le lien seulement.
                        RondVerre(
                          icone: 'partager',
                          semantique: 'Partager',
                          onTap: () => bulle(context, 'Le lien du lieu est copié.'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MotsQuiMontent(
                      lieu.nom,
                      style: Textes.titre.copyWith(fontSize: 28, letterSpacing: -0.84, height: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Monte(
                            delai: const Duration(milliseconds: 400),
                            child: Row(
                              children: [
                                const Icone('lieu', taille: 17, couleur: Couleurs.discret),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${lieu.region} · ${lieu.nombre} photos',
                                    overflow: TextOverflow.ellipsis,
                                    style: Textes.libelle.copyWith(fontSize: 14, color: Couleurs.discret),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Le bouton « Y aller », mis de côté avec _yAller ci-dessus :
                        // const SizedBox(width: 12),
                        // Monte(
                        //   delai: const Duration(milliseconds: 500),
                        //   child: BoutonVerre(
                        //     texte: 'Y aller',
                        //     plein: true,
                        //     large: false,
                        //     widgetIcone: const Icone('y-aller', taille: 20),
                        //     onTap: () => _yAller(context, lieu),
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            // Comme Pinterest : la mosaïque va presque au bord, 5 px partout.
            padding: EdgeInsets.fromLTRB(5, 0, 5, hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverToBoxAdapter(
              child: MosaiquePublications(
                publications: publications,
                coulisses: true,
                onTap: (i) => context.push(Routes.photo('${lieu.id}-$i')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
