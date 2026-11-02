// La photo en plein écran, dans le format où elle a été prise (repris de usw_mobile) :
// rien n'est recadré. On zoome à deux doigts, on la ferme d'un glisser vers le bas.
// Elle passe au-dessus de la barre d'onglets (navigateur racine).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/widgets/verre.dart';

void ouvrirVisionneuse(BuildContext context, String photo) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Durees.ecran,
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, _) => EcranVisionneuse(photo: photo, animation: animation),
    ),
  );
}

class EcranVisionneuse extends StatefulWidget {
  const EcranVisionneuse({super.key, required this.photo, required this.animation});

  final String photo;
  final Animation<double> animation;

  @override
  State<EcranVisionneuse> createState() => _EcranVisionneuseState();
}

class _EcranVisionneuseState extends State<EcranVisionneuse> {
  final _zoom = TransformationController();
  late final Animation<double> _entree = CurvedAnimation(
    parent: widget.animation,
    curve: Courbes.signature,
    reverseCurve: Courbes.interface,
  );
  double _glisse = 0;
  bool _zoome = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final zoome = _zoom.value.getMaxScaleOnAxis() > 1.01;
      if (zoome != _zoome) setState(() => _zoome = zoome);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _fermer() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final hauteur = MediaQuery.sizeOf(context).height;
    // En glissant vers le bas, le fond s'éclaircit et la photo suit le doigt.
    final reste = (1 - _glisse.abs() / (hauteur * 0.5)).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AnimatedBuilder(
        animation: _entree,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: _entree.value * reste)),
            child!,
          ],
        ),
        // La photo arrive en grandissant un peu (transform et opacité seulement).
        child: FadeTransition(
          opacity: _entree,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(_entree),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onVerticalDragUpdate: _zoome ? null : (d) => setState(() => _glisse += d.delta.dy),
                    onVerticalDragEnd: _zoome
                        ? null
                        : (d) {
                            if (_glisse.abs() > 120 || d.velocity.pixelsPerSecond.dy.abs() > 900) {
                              _fermer();
                            } else {
                              setState(() => _glisse = 0);
                            }
                          },
                    child: Transform.translate(
                      offset: Offset(0, _glisse),
                      child: InteractiveViewer(
                        transformationController: _zoom,
                        minScale: 1,
                        maxScale: 5,
                        panEnabled: _zoome,
                        child: Center(
                          child: Image.asset(
                            'assets/images/${widget.photo}.webp',
                            fit: BoxFit.contain,
                            semanticLabel: 'Photo en plein écran',
                            errorBuilder: (context, _, _) =>
                                const ColoredBox(color: Couleurs.photoVide, child: SizedBox.expand()),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: haut + 8,
                    left: 12,
                    right: 12,
                    child: Opacity(
                      opacity: reste,
                      child: Row(
                        children: [
                          RondVerre(
                            icone: 'fermer',
                            semantique: 'Fermer',
                            surPhoto: true,
                            encre: Colors.white,
                            onTap: _fermer,
                          ),
                          const Spacer(),
                          // Télécharger l'original (E08) est hors du MVP : un simple message.
                          Appuyable(
                            semantique: "Télécharger l'original",
                            onTap: () => bulle(context, "L'original sera téléchargé en entier."),
                            child: Verre(
                              rayon: 22,
                              surFond: false,
                              ombre: false,
                              child: SizedBox(
                                height: 44,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icone('telecharger', taille: 20, couleur: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('Original', style: Textes.bouton.copyWith(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
