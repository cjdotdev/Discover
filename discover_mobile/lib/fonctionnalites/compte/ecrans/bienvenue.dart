import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/session/session.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/progression.dart';

/// E01 Bienvenue : trois pages qui avancent seules toutes les six secondes.
class EcranBienvenue extends StatefulWidget {
  const EcranBienvenue({super.key});

  @override
  State<EcranBienvenue> createState() => _EcranBienvenueState();
}

class _EcranBienvenueState extends State<EcranBienvenue> with SingleTickerProviderStateMixin {
  static const _pages = [
    (
      image: 'culture',
      titre: 'Des lieux, en vraies photos',
      texte: "Chaque photo et chaque reel de Discover a été pris sur place, par quelqu'un qui y était.",
    ),
    (
      image: 'mer',
      titre: "Chaque photo dit d'où elle vient",
      texte: "Le téléphone, la date et le lieu de la prise sont lus dans le fichier, ou indiqués par l'auteur.",
    ),
    (
      image: 'couchers',
      titre: "Envie d'y aller ?",
      texte: "Touchez « Y aller » : Maps ouvre l'itinéraire jusqu'au lieu de la photo.",
    ),
  ];

  final _pager = PageController();
  late final AnimationController _minuteur = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  int _page = 0;

  bool get _derniere => _page == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    _minuteur.addStatusListener((etat) {
      if (etat == AnimationStatus.completed && !_derniere) _allerA(_page + 1);
    });
    _minuteur.forward();
  }

  @override
  void dispose() {
    _minuteur.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _allerA(int page) => _pager.animateToPage(page, duration: Durees.ecran, curve: Courbes.signature);

  void _surChangementDePage(int page) {
    setState(() => _page = page);
    _minuteur.forward(from: 0);
  }

  Future<void> _terminer(String destination) async {
    await Session.instance.marquerBienvenueVue();
    if (mounted) context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurFormulaire),
            child: Padding(
              padding: EdgeInsets.fromLTRB(marge, 8, marge, 16),
              child: Column(
                children: [
                  Progression(etape: _page, total: _pages.length),
                  SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _derniere ? null : Lien('Passer', discret: true, onTap: () => _terminer(Routes.entree)),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pager,
                      itemCount: _pages.length,
                      onPageChanged: _surChangementDePage,
                      itemBuilder: (context, i) =>
                          _Page(index: i, image: _pages[i].image, titre: _pages[i].titre, texte: _pages[i].texte),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Bouton(
                    texte: _derniere ? 'Commencer' : 'Suivant',
                    fleche: true,
                    onTap: () => _derniere ? _terminer(Routes.entree) : _allerA(_page + 1),
                  ),
                  if (_derniere) Lien('Explorer sans compte', discret: true, onTap: () => _terminer(Routes.accueil)),
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
  const _Page({required this.index, required this.image, required this.titre, required this.texte});

  final int index;
  final String image;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Mesures.rayonPhoto),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/$image.webp', fit: BoxFit.cover),
                    if (index == 1) const Positioned(left: 12, bottom: 12, child: _InfosDeCapture()),
                    if (index == 2) ...const [
                      Center(child: Icone('epingle', taille: 54)),
                      Positioned(left: 0, right: 0, bottom: 14, child: Center(child: _BoutonYAller())),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(titre, style: Textes.titre),
        const SizedBox(height: 10),
        Text(texte, style: Textes.discret),
      ],
    );
  }
}

// Ce que porte chaque photo : le téléphone, la date et le lieu.
class _InfosDeCapture extends StatelessWidget {
  const _InfosDeCapture();

  static const _infos = [
    ('telephone', 'Le téléphone de la prise'),
    ('calendrier', "La date et l'heure"),
    ('lieu', 'Le lieu'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icone, texte) in _infos)
          Container(
            height: 34,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Couleurs.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icone(icone, taille: 17, couleur: Couleurs.texte),
                const SizedBox(width: 7),
                Text(
                  texte,
                  style: Textes.petit.copyWith(color: Couleurs.texte, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BoutonYAller extends StatelessWidget {
  const _BoutonYAller();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: Couleurs.ocean, borderRadius: BorderRadius.circular(Mesures.rayonBouton)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icone('y-aller', taille: 19, couleur: Colors.white),
          const SizedBox(width: 9),
          Text('Y aller', style: Textes.bouton.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
