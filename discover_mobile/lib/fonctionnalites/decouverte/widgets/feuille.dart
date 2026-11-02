// Les feuilles (les filtres, les options d'un profil), à la manière d'iOS 26 :
// un panneau de verre qui flotte en bas, à distance des bords. Repris de
// usw_mobile ; la lentille (un shader déclaré dans pubspec.yaml) n'y est pas :
// le fond est seulement dépoli, comme usw_mobile le fait quand le shader manque.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import 'jetons.dart';
import 'verre.dart';

Future<T?> montrerFeuille<T>(BuildContext context, {required String titre, required WidgetBuilder contenu}) =>
    Navigator.of(context, rootNavigator: true).push<T>(_RouteFeuille<T>(titre: titre, contenu: contenu));

/// L'ouverture façon iOS : la feuille naît en bas comme une pastille étroite,
/// s'étire vers le haut et s'élargit avec un ressort qui dépasse un peu, puis
/// se pose. La fermeture la rétracte vers le bas, plus vite.
class _RouteFeuille<T> extends PopupRoute<T> {
  _RouteFeuille({required this.titre, required this.contenu});

  final String titre;
  final WidgetBuilder contenu;

  @override
  Color? get barrierColor => Teintes.hsl(229, 30, 10, 0.18);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fermer';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 620);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => _Feuille(
    titre: titre,
    child: Builder(builder: contenu),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return FadeTransition(opacity: animation, child: child);
    final forme = CurvedAnimation(parent: animation, curve: CourbesPlus.ressort, reverseCurve: Curves.easeInCubic);
    final apparition = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.3),
      reverseCurve: const Interval(0.4, 1),
    );
    return FadeTransition(
      opacity: apparition,
      child: AnimatedBuilder(
        animation: forme,
        builder: (context, enfant) {
          final v = forme.value;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.translationValues(0, (1 - v) * 90, 0)
              ..scaleByDouble(0.62 + 0.38 * v, 0.35 + 0.65 * v, 1, 1),
            child: enfant,
          );
        },
        child: child,
      ),
    );
  }
}

class _Feuille extends StatefulWidget {
  const _Feuille({required this.titre, required this.child});

  final String titre;
  final Widget child;

  @override
  State<_Feuille> createState() => _FeuilleState();
}

class _FeuilleState extends State<_Feuille> {
  static const _rayon = 32.0;

  // Tirée vers le bas : elle suit le doigt, et se ferme si on la lâche assez bas.
  double _tiree = 0;

  void _lacher(DragEndDetails d) {
    if (_tiree > 110 || (d.primaryVelocity ?? 0) > 700) {
      Navigator.of(context).pop();
    } else {
      setState(() => _tiree = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final bas = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onVerticalDragUpdate: (d) => setState(() => _tiree = (_tiree + d.delta.dy).clamp(0.0, double.infinity)),
        onVerticalDragEnd: _lacher,
        child: AnimatedContainer(
          duration: _tiree == 0 ? const Duration(milliseconds: 380) : Duration.zero,
          curve: CourbesPlus.ressort,
          transform: Matrix4.translationValues(0, _tiree, 0),
          padding: EdgeInsets.fromLTRB(8, 0, 8, bas + 8),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520, maxHeight: taille.height * 0.72),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_rayon),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  // Assez de blanc pour que rien ne se lise à travers. Une Material :
                  // les lignes à toucher y dessinent leur appui.
                  child: Material(
                    color: Couleurs.surface.withValues(alpha: 0.62),
                    child: Verre(
                      rayon: _rayon,
                      surFond: false,
                      ombre: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // La poignée : on peut tirer la feuille vers le bas.
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 10, bottom: 12),
                              width: 38,
                              height: 5,
                              decoration: BoxDecoration(color: Teintes.trait, borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Semantics(header: true, child: Text(widget.titre, style: Textes.sousTitre)),
                          ),
                          Flexible(child: widget.child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une ligne d'options dans une feuille : une icône à l'encre, un texte ; en
/// rouge pour ce qui retire ou signale (bloquer, signaler).
class LigneFeuille extends StatelessWidget {
  const LigneFeuille({super.key, required this.icone, required this.texte, required this.onTap, this.danger = false});

  final String icone;
  final String texte;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final couleur = danger ? Couleurs.erreur : Couleurs.texte;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icone(icone, taille: 23, couleur: couleur),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                texte,
                style: Textes.corps.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: couleur),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
