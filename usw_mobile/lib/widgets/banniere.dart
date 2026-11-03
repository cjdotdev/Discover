// Le message apres une action (E37 « bulles »), a la maniere d iOS et des
// notifications de SafeVault : une banniere de verre depoli descend du haut
// de l ecran avec l icone de USW, dit ce qui vient de se passer, puis se
// retire seule (5,2 s), d un toucher, ou d un balayage : elle suit le doigt
// dans tous les sens et part dans celui ou on la lance. Trois au plus, l une
// sous l autre.
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../outils/langue.dart';
import '../theme/jetons.dart';
import 'icone.dart';
import 'verre.dart';

void bulle(BuildContext context, String texte, {String titre = 'Discover', String? icone}) {
  final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) return;
  _Bannieres.instance.montrer(overlay, titre, texte);
}

class _Annonce {
  _Annonce(this.titre, this.texte);

  final String titre;
  final String texte;
  final cle = UniqueKey();
}

class _Bannieres {
  _Bannieres._();
  static final instance = _Bannieres._();

  final _liste = <_Annonce>[];
  OverlayEntry? _entree;

  void montrer(OverlayState overlay, String titre, String texte) {
    if (_liste.length >= 3) _liste.removeAt(0);
    _liste.add(_Annonce(titre, texte));
    // L application reconstruite entre-temps : l ancienne place n existe plus.
    if (_entree == null || !_entree!.mounted) {
      _entree = OverlayEntry(
        builder: (_) => _Pile(annonces: _liste, onFin: _retirer),
      );
      overlay.insert(_entree!);
    } else {
      _entree!.markNeedsBuild();
    }
  }

  void _retirer(_Annonce annonce) {
    _liste.remove(annonce);
    if (_liste.isEmpty) {
      _entree?.remove();
      _entree = null;
    } else {
      _entree?.markNeedsBuild();
    }
  }
}

class _Pile extends StatelessWidget {
  const _Pile({required this.annonces, required this.onFin});

  final List<_Annonce> annonces;
  final void Function(_Annonce) onFin;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final largeur = MediaQuery.sizeOf(context).width;
    return Positioned(
      top: haut + 8,
      left: 0,
      right: 0,
      // Au-dessus de toute l application, hors des ecrans : elle prend ici
      // le style de texte de USW (police, pas de soulignement d alerte).
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: SizedBox(
            width: (largeur - 24).clamp(0.0, 420.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in annonces)
                  Padding(
                    key: a.cle,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Banniere(annonce: a, onFin: () => onFin(a)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banniere extends StatefulWidget {
  const _Banniere({required this.annonce, required this.onFin});

  final _Annonce annonce;
  final VoidCallback onFin;

  @override
  State<_Banniere> createState() => _BanniereState();
}

class _BanniereState extends State<_Banniere> with TickerProviderStateMixin {
  // Entree au ressort (0,6 s), sortie a la courbe d interface (0,35 s).
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), reverseDuration: const Duration(milliseconds: 350))..forward();
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Courbes.ressort, reverseCurve: Courbes.interface.flipped);
  Timer? _minuterie;

  // Le balayage : la banniere suit le doigt ; lancee (ou tiree assez loin), elle part dans ce
  // sens ; lachee avant, elle revient en place.
  Offset _glisse = Offset.zero;
  Offset _depart = Offset.zero;
  Offset _arrivee = Offset.zero;
  bool _part = false;
  late final AnimationController _jet = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _jetCourbe = CurvedAnimation(parent: _jet, curve: Curves.easeOutCubic);

  Offset get _decalage => _jet.isAnimating || _part ? Offset.lerp(_depart, _arrivee, _jetCourbe.value)! : _glisse;

  void _bouger(DragUpdateDetails d) {
    if (_part) return;
    _minuterie?.cancel();
    _jet.stop();
    setState(() => _glisse += d.delta);
  }

  void _lacher(DragEndDetails d) {
    if (_part) return;
    final v = d.velocity.pixelsPerSecond;
    final lancee = v.distance > 650;
    final sens = lancee ? v : _glisse;
    _depart = _glisse;
    if ((lancee || _glisse.distance > 80) && sens.distance > 0) {
      _part = true;
      _arrivee = sens / sens.distance * MediaQuery.sizeOf(context).longestSide;
      _jet.forward(from: 0).whenComplete(() {
        if (mounted) widget.onFin();
      });
    } else {
      _arrivee = Offset.zero;
      _jet.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _glisse = Offset.zero);
      });
      _minuterie = Timer(const Duration(milliseconds: 3000), _sortir);
    }
  }

  @override
  void initState() {
    super.initState();
    _minuterie = Timer(const Duration(milliseconds: 5200), _sortir);
  }

  void _sortir() {
    _minuterie?.cancel();
    if (!mounted || _c.status == AnimationStatus.reverse) return;
    _c.reverse().whenComplete(() {
      if (mounted) widget.onFin();
    });
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _jet.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenu = Semantics(
      liveRegion: true,
      label: '${widget.annonce.titre} : ${widget.annonce.texte}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: _sortir,
          onPanUpdate: _bouger,
          onPanEnd: _lacher,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            // Elle passe au-dessus du contenu : ici le verre est depoli, pour
            // que le message reste lisible quoi qu il y ait dessous. Le flou ne
            // couvre que la banniere, et seulement le temps qu elle est la.
            child: BackdropFilter(
              filter: ImageFilter.compose(outer: ImageFilter.blur(sigmaX: 18, sigmaY: 18), inner: const ColorFilter.matrix(_saturation)),
              child: Verre(
                rayon: 24,
                surFond: false,
                ombre: false,
                child: ColoredBox(
                  color: Couleurs.surface.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                    child: Row(
                      children: [
                        // L icone de l application, comme sur une notification d iOS : blanche
                        // le jour, noire la nuit (comme l icone du telephone) ; le logo prend la
                        // version qui se detache de ce fond, jamais blanc sur blanc ni noir sur noir.
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Couleurs.sombre ? Colors.black : Colors.white,
                            border: Border.all(color: Couleurs.sombre ? Colors.white.withValues(alpha: 0.14) : Couleurs.hsl(229, 30, 40, 0.14)),
                          ),
                          child: LogoUsw(taille: 30, sombre: Couleurs.sombre),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.annonce.titre,
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Couleurs.texte),
                                    ),
                                  ),
                                  Text(t('maintenant'), style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(widget.annonce.texte, style: TextStyle(fontSize: 14, height: 1.35, color: Couleurs.texte.withValues(alpha: 0.72))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Elle descend du haut en grandissant un peu, puis suit le doigt : transform et opacite.
    return AnimatedBuilder(
      animation: Listenable.merge([_t, _jet]),
      builder: (context, child) {
        final d = _decalage;
        return Transform.translate(
          offset: d,
          child: Opacity(
            opacity: (1 - d.distance / 420).clamp(0.0, 1.0),
            child: FractionalTranslation(
              translation: Offset(0, -1.4 * (1 - _t.value)),
              child: Transform.scale(scale: 0.92 + 0.08 * _t.value, child: child),
            ),
          ),
        );
      },
      child: FadeTransition(opacity: _c, child: contenu),
    );
  }
}

/// Saturation x 1,8 (le saturate(1.8) de SafeVault).
const _saturation = <double>[
  1.6038, -0.5724, -0.0314, 0, 0, //
  -0.1962, 1.2276, -0.0314, 0, 0, //
  -0.1962, -0.5724, 1.7686, 0, 0, //
  0, 0, 0, 1, 0, //
];
