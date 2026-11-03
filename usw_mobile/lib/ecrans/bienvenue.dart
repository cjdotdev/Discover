// E01 Bienvenue : trois ecrans qui avancent seuls (6 s). Des lieux en vraies
// photos ; chaque photo dit d ou elle vient ; Y aller. Creer un compte, se
// connecter, ou explorer sans compte.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../donnees/catalogue.dart';
import '../donnees/modeles.dart';
import '../outils/images_reseau.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/champ.dart';
import '../widgets/icone.dart';
import '../widgets/mouvement.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';

class EcranBienvenue extends StatefulWidget {
  const EcranBienvenue({super.key});

  @override
  State<EcranBienvenue> createState() => _EcranBienvenueState();
}

class _EcranBienvenueState extends State<EcranBienvenue> with SingleTickerProviderStateMixin {
  static List<(String, String)> get _pages => [
    (t('Des lieux, en vraies photos'), t("Chaque photo et chaque reel de Discover a été pris sur place, par quelqu'un qui y était.")),
    (t("Chaque photo dit d'où elle vient"), t("Le téléphone, la date et le lieu de la prise sont lus dans le fichier, ou indiqués par l'auteur.")),
    (t("Envie d'y aller ?"), t("Touchez « Y aller » : Maps ouvre l'itinéraire jusqu'au lieu de la photo.")),
  ];

  final _pager = PageController();
  late final AnimationController _avance = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _avance.addStatusListener((s) {
      if (s == AnimationStatus.completed && _page < _pages.length - 1) _aller(_page + 1);
    });
    _avance.forward();
  }

  @override
  void dispose() {
    _avance.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _aller(int page) {
    _pager.animateToPage(page, duration: Durees.ecran, curve: Courbes.signature);
  }

  void _surPage(int page) {
    setState(() => _page = page);
    _avance.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final derniere = _page == _pages.length - 1;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: EdgeInsets.fromLTRB(marge, 8, marge, 20),
              child: Column(
                children: [
                  Progression(etape: _page, avance: derniere ? null : _avance),
                  SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        opacity: derniere ? 0 : 1,
                        duration: Durees.interface,
                        child: IgnorePointer(
                          ignoring: derniere,
                          child: Lien(t('Passer'), discret: true, onTap: () => context.go('/entree')),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pager,
                      onPageChanged: _surPage,
                      itemCount: _pages.length,
                      itemBuilder: (context, i) => _Page(index: i, titre: _pages[i].$1, texte: _pages[i].$2),
                    ),
                  ),
                  const SizedBox(height: 26),
                  BoutonVerre(texte: derniere ? t('Commencer') : t('Suivant'), plein: true, onTap: () => derniere ? context.go('/entree') : _aller(_page + 1)),
                  AnimatedSize(
                    duration: Durees.interface,
                    curve: Courbes.interface,
                    child: derniere
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Lien(t('Explorer sans compte'), discret: true, onTap: () => context.go('/accueil')),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.index, required this.titre, required this.texte});

  final int index;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Center(
          child: ListenableBuilder(listenable: Listenable.merge([Catalogue.instance, ImagesReseau.pretes]), builder: (context, _) => _visuel(context)),
        ),
      ),
      MotsQuiMontent(titre, style: Textes.titre),
      const SizedBox(height: 10),
      Monte(
        delai: const Duration(milliseconds: 350),
        child: Text(texte, style: Textes.discret),
      ),
    ],
  );

  Widget _visuel(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    // Les photos des lieux recus, de lieux differents (une image du paquet tant que la sienne n est pas la).
    final photos = Catalogue.instance.vitrine(6);
    return switch (index) {
      0 => SizedBox(
        width: (largeur * 0.64).clamp(0, 300),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Pile(photos: photos.take(4).toList(), rayon: 26),
        ),
      ),
      1 => _capture((largeur * 0.72).clamp(0, 320), photos[4]),
      _ => _DemoPhoto(
        photo: photos[5],
        largeur: (largeur * 0.72).clamp(0, 320),
        centre: const Monte(delai: Duration(milliseconds: 300), distance: 30, child: Icone('epingle', taille: 54)),
        bas: Center(child: _BoutonYAller(texte: t('Y aller'))),
      ),
    };
  }

  // Une vraie publication, avec son telephone, sa date et son lieu (verifiee d abord, sinon
  // declaree par son auteur, avec son badge). Sans elle (rien de recu), une photo de la
  // vitrine et ce que chaque photo indique.
  Widget _capture(double largeur, String secours) {
    final exemple = _exemple();
    if (exemple == null) {
      return _DemoPhoto(
        photo: secours,
        largeur: largeur,
        bas: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Puce(icone: 'telephone', texte: t('Le téléphone de la prise'), rang: 0),
            _Puce(icone: 'calendrier', texte: t('La date et l’heure'), rang: 1),
            _Puce(icone: 'lieu', texte: t('Le lieu'), rang: 2),
          ],
        ),
      );
    }
    final (p, lieu) = exemple;
    return _DemoPhoto(
      photo: p.photo,
      largeur: largeur,
      haut: BadgeCapture(verifie: p.verifiee),
      bas: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Puce(icone: 'telephone', texte: p.appareil, rang: 0),
          _Puce(icone: 'calendrier', texte: dateLongue(p.priseLe!), rang: 1),
          _Puce(icone: 'lieu', texte: lieu, rang: 2),
        ],
      ),
    );
  }

  static (Publication, String)? _exemple() {
    final exemple = Catalogue.instance.exempleDeCapture();
    if (exemple == null) return null;
    final (p, l) = exemple;
    final nom = (p.lieuNom ?? '').isNotEmpty ? p.lieuNom! : l.nom;
    return (p, l.region.isEmpty || nom != l.nom ? nom : '$nom, ${l.region}');
  }
}

class _DemoPhoto extends StatelessWidget {
  const _DemoPhoto({required this.photo, required this.largeur, this.haut, this.bas, this.centre});

  final String photo;
  final double largeur;
  final Widget? haut;
  final Widget? bas;
  final Widget? centre;

  @override
  Widget build(BuildContext context) => Container(
    width: largeur,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(26)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Photo(photo),
            if (haut != null) Positioned(top: 12, left: 12, child: haut!),
            if (centre != null) Center(child: centre),
            if (bas != null) Positioned(left: 12, right: 12, bottom: 12, child: bas!),
          ],
        ),
      ),
    ),
  );
}

class _Puce extends StatelessWidget {
  const _Puce({required this.icone, required this.texte, required this.rang});

  final String icone;
  final String texte;
  final int rang;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Monte(
      delai: Duration(milliseconds: 400 + 120 * rang),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Couleurs.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(17)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icone(icone, taille: 17),
            const SizedBox(width: 7),
            // Pendant que la page glisse, la photo est plus etroite : le texte
            // s efface au bord au lieu de deborder.
            Flexible(
              child: Text(
                texte,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Couleurs.texte),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BoutonYAller extends StatelessWidget {
  const _BoutonYAller({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) => Verre(
    teinte: TeinteVerre.ocean,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icone('y-aller', taille: 19, couleur: Colors.white),
          const SizedBox(width: 9),
          Text(texte, style: Textes.bouton.copyWith(color: Colors.white)),
        ],
      ),
    ),
  );
}
