// La photo en plein ecran, dans le format ou elle a ete prise (portrait
// 9:16, paysage, carre...) : rien n est recadre. Elle se decode a la taille de
// l ecran ; au zoom, la 4K arrive si le telephone la porte (sinon la 2 160 px
// entiere). On la ferme d un glisser vers le bas, et elle se telecharge d ici.
// Elle passe au-dessus de la barre d onglets (navigateur racine).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../outils/capacites.dart';
import '../donnees/catalogue.dart';
import '../donnees/telechargements.dart';
import '../outils/langue.dart';
import '../outils/videos.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';

/// Un reel en plein ecran, avec le son, en boucle ; un toucher le met en pause. Deja lu sans le
/// son sur la page, il continue la ou il en est (le meme lecteur), sans rien recharger.
void ouvrirLecture(BuildContext context, String video, {String? affiche, List<String> replis = const []}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => _EcranLecture(video: video, affiche: affiche, replis: replis),
  ),
);

class _EcranLecture extends StatefulWidget {
  const _EcranLecture({required this.video, this.affiche, this.replis = const []});

  final String video;

  /// La meme en plus leger : deja sur le telephone, elle part aussitot.
  final List<String> replis;

  /// L image de la video : montee tout de suite, jamais un ecran noir pendant que la video arrive.
  final String? affiche;

  @override
  State<_EcranLecture> createState() => _EcranLectureState();
}

class _EcranLectureState extends State<_EcranLecture> {
  // Un fichier du telephone, la video deja gardee (aussitot), ou la video servie par Discover.
  VideoPlayerController? _lecteur;
  bool _rate = false;

  /// Le lecteur de la page, a lui rendre en sortant.
  bool _empruntee = false;

  /// Rendu a la page : il reste a l ecran pendant la sortie, mais ne se ferme plus ici.
  bool _rendue = false;

  @override
  void initState() {
    super.initState();
    final l = VideoMuette.emprunter(widget.video);
    if (l == null) {
      _ouvrir();
      return;
    }
    _lecteur = l;
    _empruntee = true;
    unawaited(l.setVolume(1));
    unawaited(l.setLooping(true));
    unawaited(l.play());
  }

  // En sortant : la video retourne a la page, qui la garde en lecture sans le son.
  void _rendre() {
    final l = _lecteur;
    if (!_empruntee || l == null) return;
    _empruntee = false;
    _rendue = VideoMuette.rendre(widget.video, l);
  }

  Future<void> _ouvrir() async {
    setState(() => _rate = false);
    final l = await Videos.instance.lecteur(widget.video, replis: widget.replis);
    if (!mounted) {
      l.dispose();
      return;
    }
    _lecteur = l;
    try {
      await l.initialize();
      if (!mounted) return;
      await l.setLooping(true);
      await l.play();
      setState(() {});
    } catch (_) {
      _lecteur = null;
      unawaited(l.dispose());
      if (mounted) setState(() => _rate = true);
    }
  }

  @override
  void dispose() {
    _rendre();
    if (!_rendue) _lecteur?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lecteur;
    final prete = l != null && l.value.isInitialized;
    return PopScope(
      onPopInvokedWithResult: (sortie, _) {
        if (sortie) _rendre();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (!prete && widget.affiche != null) Photo(widget.affiche!, fit: BoxFit.contain),
              GestureDetector(
                onTap: prete ? () => setState(() => l.value.isPlaying ? l.pause() : l.play()) : null,
                child: Center(
                  child: prete ? AspectRatio(aspectRatio: l.value.aspectRatio, child: VideoPlayer(l)) : const SizedBox.expand(),
                ),
              ),
              if (!prete && !_rate) const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              if (_rate)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t('La vidéo n’a pas pu se charger.'), style: const TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 12),
                      BoutonVerre(texte: t('Réessayer'), large: false, onTap: _ouvrir),
                    ],
                  ),
                ),
              Positioned(
                left: 12,
                top: MediaQuery.paddingOf(context).top + 8,
                child: RondVerre(icone: 'retour', semantique: t('Fermer'), surPhoto: true, onTap: () => Navigator.pop(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `contenu` : la publication sur le serveur, pour telecharger sa plus grande taille ;
/// `tresGrande` : sa 4K, chargee au zoom.
void ouvrirVisionneuse(BuildContext context, String photo, {String? contenu, String? tresGrande, Map<String, ({int largeur, int hauteur})> tailles = const {}}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Durees.ecran,
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, _) => EcranVisionneuse(photo: photo, contenu: contenu, tresGrande: tresGrande, tailles: tailles, animation: animation),
    ),
  );
}

class EcranVisionneuse extends StatefulWidget {
  const EcranVisionneuse({super.key, required this.photo, required this.animation, this.contenu, this.tresGrande, this.tailles = const {}});

  final String photo;
  final String? contenu;
  final String? tresGrande;
  final Map<String, ({int largeur, int hauteur})> tailles;
  final Animation<double> animation;

  @override
  State<EcranVisionneuse> createState() => _EcranVisionneuseState();
}

class _EcranVisionneuseState extends State<EcranVisionneuse> {
  final _zoom = TransformationController();
  late final Animation<double> _entree = CurvedAnimation(parent: widget.animation, curve: Courbes.signature, reverseCurve: Courbes.interface);
  double _glisse = 0;
  bool _zoome = false;

  // L image plus nette, decodee entiere, une fois prete (le zoom la demande une fois).
  ImageProvider? _nette;
  bool _netteDemandee = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final echelle = _zoom.value.getMaxScaleOnAxis();
      final zoome = echelle > 1.01;
      if (zoome != _zoome) setState(() => _zoome = zoome);
      if (echelle > 1.4 && !_netteDemandee) _plusNette();
    });
  }

  // La 4K si elle existe et que le telephone la porte ; sinon la grande taille entiere.
  void _plusNette() {
    _netteDemandee = true;
    final t = widget.tailles['3840'];
    final source = widget.tresGrande != null && (t == null ? Capacites.instance.porteLa4K : Capacites.instance.peutAfficher(t.largeur, t.hauteur)) ? widget.tresGrande! : widget.photo;
    final image = imageDePhoto(source, largeur: null);
    precacheImage(image, context, onError: (_, _) {}).then((_) {
      if (mounted) setState(() => _nette = image);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _fermer() => Navigator.of(context).pop();

  // Un seul doigt, sans zoom : il tire la photo pour la fermer. Deux doigts : le zoom, dans tous
  // les sens (un glissement vertical a cote captait le pincement des qu il montait ou descendait).
  bool _tire = false;
  Offset _toucher = Offset.zero;

  void _debut(ScaleStartDetails d) => _tire = d.pointerCount == 1 && !_zoome;

  void _pendant(ScaleUpdateDetails d) {
    if (d.pointerCount > 1) {
      _tire = false;
      if (_glisse != 0) setState(() => _glisse = 0);
      return;
    }
    if (_tire) setState(() => _glisse += d.focalPointDelta.dy);
  }

  void _fin(ScaleEndDetails d) {
    if (!_tire) return;
    _tire = false;
    if (_glisse.abs() > 120 || d.velocity.pixelsPerSecond.dy.abs() > 900) {
      _fermer();
    } else {
      setState(() => _glisse = 0);
    }
  }

  // Deux touchers : zoom x2,5 la ou le doigt s est pose ; encore deux : retour a la photo entiere.
  void _doubleToucher() {
    if (_zoome) {
      _zoom.value = Matrix4.identity();
      return;
    }
    const x = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-_toucher.dx * (x - 1), -_toucher.dy * (x - 1), 0, 1)
      ..scaleByDouble(x, x, 1, 1);
  }

  // Le bouton Telecharger de la visionneuse prend la plus grande taille que ce telephone affiche.
  String? _tailleSure() {
    for (final t in ['3840', '2160', '1080']) {
      final d = widget.tailles[t];
      if (d != null && Capacites.instance.peutAfficher(d.largeur, d.hauteur)) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final hauteur = MediaQuery.sizeOf(context).height;
    // En glissant vers le bas, le fond s eclaircit et la photo suit le doigt.
    final reste = (1 - _glisse.abs() / (hauteur * 0.5)).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: barreSombre,
      child: AnimatedBuilder(
        animation: _entree,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: _entree.value * reste)),
            child!,
          ],
        ),
        // La photo arrive en grandissant un peu (transform et opacite seulement).
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
                    onDoubleTapDown: (d) => _toucher = d.localPosition,
                    onDoubleTap: _doubleToucher,
                    child: Transform.translate(
                      offset: Offset(0, _glisse),
                      child: InteractiveViewer(
                        transformationController: _zoom,
                        minScale: 1,
                        maxScale: 5,
                        onInteractionStart: _debut,
                        onInteractionUpdate: _pendant,
                        onInteractionEnd: _fin,
                        child: Center(
                          child: Image(
                            // A la largeur de l ecran en pixels, puis plus nette au zoom.
                            image: _nette ?? imageDePhoto(widget.photo, largeur: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round().clamp(720, 2160)),
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                            semanticLabel: t('Photo en plein écran'),
                            errorBuilder: (context, _, _) => ColoredBox(color: Couleurs.photoVide, child: const SizedBox.expand()),
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
                          RondVerre(icone: 'fermer', semantique: t('Fermer'), surPhoto: true, encre: Colors.white, onTap: _fermer),
                          const Spacer(),
                          Appuyable(
                            semantique: t('Télécharger la photo'),
                            onTap: () async {
                              // Comme depuis la page : la notification avance, et Mes envois le garde.
                              final p = widget.contenu == null ? null : Catalogue.instance.publication(widget.contenu!);
                              final d = await Telechargements.instance.lancer(
                                titre: p?.lieuNom ?? p?.titre ?? 'Discover',
                                source: widget.photo,
                                vignette: p?.photo ?? widget.photo,
                                contenu: widget.contenu,
                                taille: _tailleSure(),
                              );
                              if (!context.mounted) return;
                              bulle(context, Telechargements.messageDe(d), icone: d.etat == EtatTelechargement.ok ? 'coche' : 'alerte');
                            },
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
                                      Text(t('Télécharger'), style: Textes.bouton.copyWith(color: Colors.white)),
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
