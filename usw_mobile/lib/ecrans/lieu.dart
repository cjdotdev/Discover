// E33 Lieu : la pile deliee. Toucher une pile de l accueil ouvre son lieu :
// toutes ses photos et ses reels en mosaique, et « Y aller » qui ouvre
// l itineraire dans Maps. Les cartes entrent facon « Coulisses » en suivant
// le defilement. Epure comme l accueil : pas d onglets Tout / Photos / Reels,
// un reel se reconnait a sa duree. Les publications viennent de
// GET /api/v1/lieux/{id}/contenus (donnees/catalogue.dart).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../outils/partage.dart';
import '../outils/chemins.dart';
import '../donnees/catalogue.dart';
import '../donnees/communaute.dart';
import '../donnees/lieux_enregistres.dart';
import '../donnees/modeles.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../widgets/feuilles.dart';
import '../widgets/page.dart';
import '../widgets/mosaique.dart';
import '../widgets/icone.dart';
import '../widgets/mouvement.dart';
import '../widgets/y_aller.dart';
import '../widgets/verre.dart';

class EcranLieu extends StatefulWidget {
  const EcranLieu({super.key, required this.lieu});

  final Lieu lieu;

  @override
  State<EcranLieu> createState() => _EcranLieuState();
}

class _EcranLieuState extends State<EcranLieu> {
  Lieu get lieu => widget.lieu;

  // Enregistre dans mes lieux (GET lieux/{id}, enregistre) ; nul tant que le serveur ne l a pas dit.
  late bool? _enregistre = LieuxEnregistres.instance.estEnregistre(lieu.id);
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    if (Communaute.instance.enLigne) {
      LieuxEnregistres.instance.lire(lieu.id).then((oui) {
        if (mounted && oui != null) setState(() => _enregistre = oui);
      });
    }
  }

  Future<void> _yAller(BuildContext context) => yAller(context, lieu);

  // Enregistrer le lieu (PUT moi/lieux/{id}), ou le retirer (DELETE) : il se retrouve dans le profil.
  Future<void> _enregistrer() async {
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour enregistrer ce lieu.'), icone: 'profil');
      return;
    }
    if (_enCours) return;
    final avant = _enregistre ?? false;
    setState(() {
      _enCours = true;
      _enregistre = !avant;
    });
    final ok = await LieuxEnregistres.instance.enregistrer(lieu.id, !avant);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      if (!ok) _enregistre = avant;
    });
    if (!ok) {
      bulle(context, avant ? t('Impossible de retirer le lieu. Réessayez.') : t('Impossible d’enregistrer le lieu. Réessayez.'), icone: 'alerte');
      return;
    }
    bulle(context, avant ? t('Lieu retiré de vos lieux enregistrés.') : t('Lieu enregistré. Retrouvez-le dans votre profil.'), icone: avant ? 'enregistrer' : 'coche');
  }

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(largeur);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Comme a l accueil : l en-tete se range quand on descend et revient
          // des qu on remonte ; les photos passent sous la barre d etat.
          SliverFloatingHeader(
            snapMode: FloatingHeaderSnapMode.scroll,
            animationStyle: AnimationStyle(duration: const Duration(milliseconds: 450), curve: Courbes.interface, reverseDuration: const Duration(milliseconds: 450), reverseCurve: Courbes.interface),
            child: ColoredBox(
              color: Couleurs.fond,
              child: Padding(
                padding: EdgeInsets.fromLTRB(marge, haut + 6, marge, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/accueil')),
                        const Spacer(),
                        RondVerre(
                          icone: 'enregistrer',
                          semantique: _enregistre == true ? t('Retirer des lieux enregistrés') : t('Enregistrer le lieu'),
                          encre: _enregistre == true ? Couleurs.ocean : null,
                          onTap: _enregistrer,
                        ),
                        const SizedBox(width: 6),
                        RondVerre(
                          icone: 'partager',
                          semantique: t('Partager'),
                          onTap: () => feuillePartager(
                            context,
                            titre: lieu.nom,
                            sousTitre: [if (lieu.region.isNotEmpty) lieu.region, nombrePublications(lieu.nombre)].join(' · '),
                            photo: lieu.photos.firstOrNull ?? '',
                            lien: '$domainePublic/l/${lieu.id}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MotsQuiMontent(
                      lieu.nom,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.84, height: 1.1, color: Couleurs.texte),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Monte(
                            delai: const Duration(milliseconds: 400),
                            child: Row(
                              children: [
                                Icone('lieu', taille: 17, couleur: Couleurs.discret),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    [if (lieu.region.isNotEmpty) lieu.region, nombrePublications(lieu.nombre)].join(' · '),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.discret),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (lieu.situe) const SizedBox(width: 12),
                        if (lieu.situe)
                          Monte(
                            delai: const Duration(milliseconds: 500),
                            child: BoutonVerre(texte: t('Y aller'), plein: true, large: false, widgetIcone: const Icone('y-aller', taille: 20), onTap: () => _yAller(context)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            // Comme Pinterest : la mosaique va presque au bord, 5 px partout.
            padding: EdgeInsets.fromLTRB(5, 0, 5, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverToBoxAdapter(
              // Les publications arrivent apres la pile : la mosaique se complete.
              child: ListenableBuilder(
                listenable: Catalogue.instance,
                builder: (context, _) {
                  final publications = publicationsDe(lieu);
                  return MosaiquePublications(
                    publications: publications,
                    coulisses: true,
                    // Par son identifiant quand il y en a un : le lien reste juste si la liste change.
                    onTap: (i) => context.push(ici(context, 'lieu/${lieu.id}/photo/${publications[i].id ?? i}')),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
