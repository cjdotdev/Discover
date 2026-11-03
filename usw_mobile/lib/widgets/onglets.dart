// La barre d onglets, en verre liquide facon iOS 26 (le modele : la barre de
// WhatsApp sur iOS 26). A plat, sans ombre : un verre clair et depoli, un
// filet de lumiere sur le bord, et la pastille de verre de l onglet choisi.
// Sous le doigt, la barre gonfle et s eclaire la ou on touche, la pastille se
// souleve en lentille transparente qui suit le doigt, grossit les icones et
// separe les couleurs sur son bord (l arc-en-ciel du prisme) ; l ecran change
// des que le doigt passe sur une icone. Au relache, tout revient avec des
// ressorts, et la barre rebondit.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../ecrans/creer.dart';
import '../outils/langue.dart';
import '../outils/reprise.dart';
import '../theme/jetons.dart';
import 'icone.dart';
import 'lentille.dart';
import 'verre.dart';

/// Les onglets visites, le dernier au bout : le bouton retour du telephone y revient (Profil,
/// puis Carte : retour ramene au Profil), comme une page. Chaque onglet n y est qu une fois.
final _ongletsVisites = <int>[];

/// La coquille des quatre onglets : la page de l onglet, et par-dessus la
/// barre de verre qui flotte en bas (Accueil, Reels, Creer, Carte, Profil).
class Coquille extends StatelessWidget {
  const Coquille({super.key, required this.navigation});

  final StatefulNavigationShell navigation;

  // Les noms se lisent a chaque construction : ils suivent la langue.
  static List<(String, String)> get _onglets => [(t('Accueil'), 'accueil'), (t('Reels'), 'reels'), (t('Carte'), 'carte'), (t('Profil'), 'profil')];

  @override
  Widget build(BuildContext context) {
    // Une prise interrompue (Android avait ferme USW) : on la reprend ici.
    if (priseRetrouvee != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) reprendrePrise(context);
      });
    }
    final bas = MediaQuery.paddingOf(context).bottom;
    final largeur = MediaQuery.sizeOf(context).width;
    final marge = Mesures.margeDe(largeur);
    final courant = navigation.currentIndex;
    if (_ongletsVisites.lastOrNull != courant) {
      _ongletsVisites
        ..remove(courant)
        ..add(courant);
    }
    // Les reels sont sombres : la barre y prend un verre fume.
    final sombre = courant == 1;

    Widget onglet(int i) {
      final (nom, icone) = _onglets[i];
      final actif = i == courant;
      return Expanded(
        child: Appuyable(
          semantique: nom,
          verre: true,
          gonflement: 0.14,
          onTap: () => navigation.goBranch(i, initialLocation: i == courant),
          child: SizedBox(
            height: Mesures.hautOnglets,
            child: Center(
              child: AnimatedSwitcher(
                duration: Durees.interface,
                child: Icone(
                  actif ? '$icone-plein' : icone,
                  key: ValueKey(actif),
                  taille: 26,
                  // Au repos, l encre attenuee : la meme famille que l icone choisie.
                  couleur: sombre ? Colors.white.withValues(alpha: actif ? 1 : 0.75) : Couleurs.texte.withValues(alpha: actif ? 1 : (Couleurs.sombre ? 0.62 : 0.55)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final creer = Expanded(
      child: Center(
        child: Appuyable(
          semantique: t('Créer'),
          verre: true,
          rayonVerre: 26,
          onTap: () => ouvrirCreer(context),
          child: const Verre(
            teinte: TeinteVerre.ocean,
            rayon: 26,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(child: Icone('plus', taille: 26, couleur: Colors.white)),
            ),
          ),
        ),
      ),
    );

    // Retour : d abord la page d avant dans l onglet (ou une page ouverte par-dessus), sinon
    // l onglet d avant ; au premier onglet visite, Android ferme Discover comme d habitude.
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (GoRouter.of(context).canPop() || _ongletsVisites.length < 2) return false;
        _ongletsVisites.removeLast();
        navigation.goBranch(_ongletsVisites.last);
        return true;
      },
      child: Scaffold(
        extendBody: true,
        body: navigation,
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(marge, 0, marge, bas + 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // L envoi en cours flotte juste au-dessus des onglets (E16).
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const Padding(padding: EdgeInsets.only(bottom: 10), child: PastilleEnvoi()),
              ),
              Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Semantics(
                    container: true,
                    label: t('Navigation principale'),
                    child: _Barre(navigation: navigation, sombre: sombre, onglet: onglet, creer: creer),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Barre extends StatefulWidget {
  const _Barre({required this.navigation, required this.sombre, required this.onglet, required this.creer});

  final StatefulNavigationShell navigation;
  final bool sombre;
  final Widget Function(int) onglet;
  final Widget creer;

  @override
  State<_Barre> createState() => _BarreState();
}

class _BarreState extends State<_Barre> with TickerProviderStateMixin {
  // Le bord gauche de la pastille, en points ; un ressort l amene a son onglet.
  late final AnimationController _x = AnimationController.unbounded(vsync: this);
  // 0 au repos, 1 sous le doigt : la pastille se souleve en lentille.
  late final AnimationController _doigt = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
  // Le gonflement de la barre : un ressort peu amorti, qui rebondit au relache.
  late final AnimationController _gonfle = AnimationController.unbounded(vsync: this);
  double _place = 0;
  double _lumiere = 0;
  bool _glisse = false;

  static const _marge = 8.0;
  static final _ressortPastille = SpringDescription.withDampingRatio(mass: 1, stiffness: 360, ratio: 0.56);
  static final _ressortBarre = SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.42);

  int get _courant => widget.navigation.currentIndex;

  // Cinq places egales ; Creer est au milieu (la 3e) et n a jamais la pastille.
  double _gauche(int onglet) => (onglet < 2 ? onglet : onglet + 1) * _place + 3;

  int? _ongletSous(double dx) {
    final rang = (dx / _place).floor().clamp(0, 4);
    if (rang == 2) return null;
    return rang < 2 ? rang : rang - 1;
  }

  void _rejoindre({double vitesse = 0}) => _x.animateWith(SpringSimulation(_ressortPastille, _x.value, _gauche(_courant), vitesse));

  @override
  void didUpdateWidget(_Barre ancien) {
    super.didUpdateWidget(ancien);
    // Un toucher sur une icone (ou un changement d onglet ailleurs) : la pastille y va.
    if (!_glisse && _place > 0 && (_x.value - _gauche(_courant)).abs() > 0.5) _rejoindre(vitesse: _x.velocity);
  }

  @override
  void dispose() {
    _x.dispose();
    _doigt.dispose();
    _gonfle.dispose();
    super.dispose();
  }

  void _poser(double dx) {
    _glisse = true;
    _x.stop();
    _doigt.forward();
    _gonfle.animateWith(SpringSimulation(_ressortBarre, _gonfle.value, 1, _gonfle.velocity));
    _suivre(dx);
  }

  void _suivre(double dx) {
    final largeur = _place - 6;
    _lumiere = dx;
    _x.value = (dx - largeur / 2).clamp(3.0, 4 * _place + 3);
    final i = _ongletSous(dx);
    if (i != null && i != _courant) {
      HapticFeedback.selectionClick();
      widget.navigation.goBranch(i);
    }
  }

  void _lever({double vitesse = 0}) {
    _glisse = false;
    _doigt.reverse();
    _gonfle.animateWith(SpringSimulation(_ressortBarre, _gonfle.value, 0, _gonfle.velocity));
    _rejoindre(vitesse: vitesse);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, contraintes) {
      final premiere = _place == 0;
      _place = (contraintes.maxWidth - 2 * _marge) / 5;
      if (premiere) _x.value = _gauche(_courant);
      final haut = Mesures.hautOnglets;
      final rayon = haut / 2;
      final nuit = widget.sombre || Couleurs.sombre;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (d) => _poser(d.localPosition.dx - _marge),
        onHorizontalDragUpdate: (d) => _suivre(d.localPosition.dx - _marge),
        onHorizontalDragEnd: (d) => _lever(vitesse: d.velocity.pixelsPerSecond.dx),
        onHorizontalDragCancel: _lever,
        child: AnimatedBuilder(
          animation: Listenable.merge([_x, _doigt, _gonfle]),
          child: SizedBox(
            height: haut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _marge),
              child: Row(children: [widget.onglet(0), widget.onglet(1), widget.creer, widget.onglet(2), widget.onglet(3)]),
            ),
          ),
          builder: (context, icones) {
            final d = Courbes.interface.transform(_doigt.value.clamp(0.0, 1.0));
            final g = _gonfle.value;
            return Transform.scale(
              // La barre gonfle sous le doigt et rebondit au relache.
              scale: 1 + 0.03 * g,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Le verre de la barre : clair et depoli, avec sa lentille au bord.
                  Lentille(
                    rayon: rayon,
                    dispersion: 1.2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(rayon),
                        color: widget.sombre ? const Color(0x47000000) : Couleurs.surface.withValues(alpha: lentilleDisponible.value ? (Couleurs.sombre ? 0.36 : 0.42) : 0.86),
                      ),
                      child: CustomPaint(
                        foregroundPainter: _Reflet(rayon: rayon, nuit: nuit, lumiere: _lumiere, eclat: g.clamp(0.0, 1.2)),
                        // Au repos, la pastille de verre est SOUS les icones.
                        child: Stack(children: [_pastille(d, nuit, dessous: true), icones!]),
                      ),
                    ),
                  ),
                  // Soulevee, elle passe AU-DESSUS des icones : sa lentille les grossit.
                  if (d > 0.01) IgnorePointer(child: _pastille(d, nuit, dessous: false)),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  Widget _pastille(double d, bool nuit, {required bool dessous}) {
    final haut = Mesures.hautOnglets - 12;
    // En vol, elle s etire un peu dans le sens du mouvement.
    final etire = 1 + (_x.velocity.abs() / 5000).clamp(0.0, 0.16);
    final largeur = (_place - 6) * (1 + 0.2 * d) * etire;
    final hauteur = haut * (1 + 0.32 * d) / etire.clamp(1.0, 1.06);
    final gauche = _marge + _x.value - (largeur - (_place - 6)) / 2;
    final rayon = hauteur / 2;
    final place = EdgeInsets.only(left: gauche, top: 6 - (hauteur - haut) / 2);
    if (dessous) {
      // La pastille de verre au repos : elle s efface quand la lentille se souleve.
      return Padding(
        padding: place,
        child: SizedBox(
          width: largeur,
          height: hauteur,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: (nuit ? 0.16 : 0.55) * (1 - d)),
              borderRadius: BorderRadius.circular(rayon),
            ),
            child: CustomPaint(
              painter: _Reflet(rayon: rayon, nuit: nuit, presence: 1 - d),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: place,
      child: Lentille(
        rayon: rayon,
        // Soulevee : de l eau qui grossit ce qu elle couvre et irise son bord.
        biseau: 10 + 8 * d,
        force: 4 + 8 * d,
        depoli: 0,
        zoom: 1 + 0.16 * d,
        dispersion: 3.5 * d,
        child: SizedBox(
          width: largeur,
          height: hauteur,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // De l eau : presque rien dans la masse, tout est au bord.
              color: Colors.white.withValues(alpha: nuit ? 0.04 : 0.08),
              borderRadius: BorderRadius.circular(rayon),
            ),
            child: CustomPaint(
              painter: _Reflet(rayon: rayon, nuit: nuit, arcEnCiel: d),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bord du verre liquide : un filet de lumiere vif en haut a gauche, plus
/// doux en bas a droite (la lumiere vient d en haut), et, sur la pastille
/// soulevee, l arc-en-ciel du prisme. A la place du doigt, une lueur.
class _Reflet extends CustomPainter {
  _Reflet({required this.rayon, required this.nuit, this.lumiere, this.eclat = 0, this.arcEnCiel = 0, this.presence = 1});

  final double rayon;
  final bool nuit;
  final double? lumiere;
  final double eclat;
  final double arcEnCiel;

  /// De 0 (efface) a 1 : la pastille de repos s efface quand la lentille se souleve.
  final double presence;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final forme = RRect.fromRectAndRadius(rect, Radius.circular(rayon));
    final k = (nuit ? 0.55 : 1.0) * presence.clamp(0.0, 1.0);

    // La lueur sous le doigt, dans la forme du verre.
    if (lumiere != null && eclat > 0.01) {
      canvas.save();
      canvas.clipRRect(forme);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.32 * eclat * k),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(lumiere! + 8, size.height / 2), radius: size.height * 1.4)),
      );
      canvas.restore();
    }

    final filet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.95 * k),
          Colors.white.withValues(alpha: 0.22 * k),
          Colors.white.withValues(alpha: 0.1 * k),
          Colors.white.withValues(alpha: 0.6 * k),
        ],
        stops: const [0, 0.35, 0.65, 1],
      ).createShader(rect);
    canvas.drawRRect(forme.deflate(0.55), filet);

    if (arcEnCiel > 0.01) {
      final prisme = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = SweepGradient(
          transform: const GradientRotation(-math.pi / 3),
          colors: [
            for (final c in const [Color(0xFFFF5A5A), Color(0xFFFFC94A), Color(0xFF6BE86B), Color(0xFF4AD6FF), Color(0xFF7A6BFF), Color(0xFFFF6BD6), Color(0xFFFF5A5A)])
              c.withValues(alpha: 0.45 * arcEnCiel),
          ],
        ).createShader(rect);
      canvas.drawRRect(forme.deflate(1.7), prisme);
    }
  }

  @override
  bool shouldRepaint(_Reflet ancien) =>
      ancien.rayon != rayon || ancien.nuit != nuit || ancien.lumiere != lumiere || ancien.eclat != eclat || ancien.arcEnCiel != arcEnCiel || ancien.presence != presence;
}
