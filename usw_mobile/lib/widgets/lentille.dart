// La lentille du verre liquide, facon iOS : derriere le verre, l image est
// legerement depolie et se courbe pres du bord (shaders/verre_liquide.frag).
// Elle demande Impeller (ImageFilter.shader) ; sinon, et pendant que le
// programme se charge, le verre reste tel quel, sans lentille. Elle se coupe
// aussi tant que le telephone chauffe ou economise (outils/sobriete.dart) :
// c est un calcul a chaque image.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../outils/sobriete.dart';
import '../theme/jetons.dart';

/// Vrai des que la lentille peut etre dessinee : le verre peut alors etre
/// plus transparent, le depoli garde le texte lisible.
final lentilleDisponible = ValueNotifier<bool>(false);

ui.FragmentProgram? _programme;

// Le programme est la, le telephone n est pas en mode leger, et sa carte
// graphique dessine bien la lentille (sinon le fond du verre sortait noir).
void _ajuster() => lentilleDisponible.value = _programme != null && !Sobriete.instance.leger && Sobriete.instance.lentillePossible;

/// A appeler au demarrage : charge le programme une fois pour toute l app.
Future<void> chargerLentille() async {
  if (!ui.ImageFilter.isShaderFilterSupported) {
    debugPrint('LENTILLE non prise en charge (pas d Impeller) : verre sans distorsion');
    return;
  }
  try {
    _programme = await ui.FragmentProgram.fromAsset('shaders/verre_liquide.frag');
    Sobriete.instance.addListener(_ajuster);
    _ajuster();
    debugPrint('LENTILLE active');
  } catch (e) {
    debugPrint('LENTILLE indisponible : $e');
  }
}

/// Dans une feuille ou une alerte, qui ont deja leur lentille : les verres poses
/// dessus (pastilles, boutons, champs) restent du verre, sans lentille a eux. Une
/// lentille par element obligeait a recopier l ecran autant de fois, a chaque
/// image : l ouverture et le defilement ramaient. iOS ne superpose pas non plus.
class SansLentille extends InheritedWidget {
  const SansLentille({super.key, required super.child});

  static bool actif(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SansLentille>() != null;

  @override
  bool updateShouldNotify(SansLentille ancien) => false;
}

/// Pose par une lentille autour de ce qu elle contient : une lentille dedans (la bulle de la
/// barre d onglets) garde sa propre lecture du fond, pour courber aussi le verre dessous.
class _DansLentille extends InheritedWidget {
  const _DansLentille({required super.child});

  @override
  bool updateShouldNotify(_DansLentille ancien) => false;
}

class Lentille extends StatefulWidget {
  const Lentille({super.key, required this.rayon, required this.child, this.biseau = 16, this.force = 9, this.depoli = 1.4, this.flou = 0, this.zoom = 1, this.dispersion = 0, this.partage = false});

  final double rayon;
  final Widget child;

  /// La largeur du bord qui courbe l image, en points.
  final double biseau;

  /// Le deplacement de l image au ras du bord, en points.
  final double force;

  /// L ecart du depoli, en points : petit, pour qu il reste leger.
  final double depoli;

  /// Un flou de plus, avant la lentille (les feuilles : le texte de dessous
  /// ne doit pas se lire). Zero pour la barre et les boutons.
  final double flou;

  /// Le grossissement au centre (la bulle de la barre d onglets : 1,16).
  final double zoom;

  /// L ecart des couleurs au bord, en points : le prisme d iOS 26 (0 : aucun).
  final double dispersion;

  /// Lit le fond avec les autres verres de sa page, une fois pour tous (les boutons de verre,
  /// nombreux et cote a cote). Jamais pour un verre pose par-dessus un autre au meme niveau
  /// (la bulle levee de la barre d onglets) : il ne verrait pas celui de dessous, ni ses icones.
  final bool partage;

  @override
  State<Lentille> createState() => _LentilleState();
}

class _LentilleState extends State<Lentille> {
  // Ce qui deplace le verre sans le redessiner : le defilement des pages qui le
  // contiennent et les transitions de sa page. Le verre se redessine alors (sans
  // se reconstruire), et sa lentille se place exactement, dans la meme image.
  Listenable? _suivis;

  // Les boutons de verre d une meme page lisent le fond une seule fois pour tous (BackdropKey),
  // au lieu d une copie de l ecran par bouton et par image. Chaque page a la sienne.
  static final _cles = Expando<BackdropKey>();
  ModalRoute<dynamic>? _route;
  bool _imbriquee = false;

  void _changer() => setState(() {});

  @override
  void initState() {
    super.initState();
    lentilleDisponible.addListener(_changer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liste = <Listenable>[];
    BuildContext? ctx = context;
    while (ctx != null) {
      final defile = Scrollable.maybeOf(ctx);
      if (defile == null) break;
      liste.add(defile.position);
      ctx = defile.context;
    }
    final route = ModalRoute.of(context);
    liste.addAll([?route?.animation, ?route?.secondaryAnimation]);
    _suivis = Listenable.merge(liste);
    _route = route;
    _imbriquee = context.dependOnInheritedWidgetOfExactType<_DansLentille>() != null;
  }

  @override
  void dispose() {
    lentilleDisponible.removeListener(_changer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SansLentille.actif(context)) return widget.child;
    return _construire(context);
  }

  Widget _construire(BuildContext context) => _Lentille(
    programme: lentilleDisponible.value ? _programme : null,
    suivis: _suivis,
    cle: widget.partage && !_imbriquee && _route != null ? (_cles[_route!] ??= BackdropKey()) : null,
    dpr: MediaQuery.devicePixelRatioOf(context),
    rayon: widget.rayon,
    biseau: widget.biseau,
    force: widget.force,
    depoli: widget.depoli,
    flou: widget.flou,
    zoom: widget.zoom,
    dispersion: widget.dispersion,
    child: _DansLentille(child: widget.child),
  );
}

class _Lentille extends SingleChildRenderObjectWidget {
  const _Lentille({
    required this.programme,
    required this.suivis,
    required this.cle,
    required this.dpr,
    required this.rayon,
    required this.biseau,
    required this.force,
    required this.depoli,
    required this.flou,
    required this.zoom,
    required this.dispersion,
    required super.child,
  });

  final ui.FragmentProgram? programme;
  final Listenable? suivis;
  final BackdropKey? cle;
  final double dpr, rayon, biseau, force, depoli, flou, zoom, dispersion;

  @override
  _RenduLentille createRenderObject(BuildContext context) => _RenduLentille()..regler(this);

  @override
  void updateRenderObject(BuildContext context, _RenduLentille rendu) => rendu.regler(this);
}

/// Le verre se mesure au moment de se dessiner : sa place exacte a l ecran,
/// echelle comprise (une feuille qui s ouvre en grandissant), sans attendre
/// l image suivante et sans rien reconstruire.
class _RenduLentille extends RenderProxyBox {
  ui.FragmentProgram? _programme;
  ui.FragmentShader? _shader;
  Listenable? _suivis;
  BackdropKey? _cle;
  double _dpr = 1, _rayon = 0, _biseau = 0, _force = 0, _depoli = 0, _flou = 0, _zoom = 1, _dispersion = 0;

  final _decoupe = LayerHandle<ClipRRectLayer>();
  final _filtre = LayerHandle<BackdropFilterLayer>();

  bool get _actif => _programme != null || _flou > 0;

  void regler(_Lentille w) {
    final avant = _actif;
    if (w.programme != _programme) {
      _programme = w.programme;
      _shader = null;
    }
    if (w.suivis != _suivis) {
      if (attached) _suivis?.removeListener(markNeedsPaint);
      _suivis = w.suivis;
      if (attached) _suivis?.addListener(markNeedsPaint);
    }
    _cle = w.cle;
    _dpr = w.dpr;
    _rayon = w.rayon;
    _biseau = w.biseau;
    _force = w.force;
    _depoli = w.depoli;
    _flou = w.flou;
    _zoom = w.zoom;
    _dispersion = w.dispersion;
    if (avant != _actif) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _actif;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _suivis?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _suivis?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _decoupe.layer = null;
    _filtre.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_actif || child == null) {
      _decoupe.layer = null;
      _filtre.layer = null;
      super.paint(context, offset);
      return;
    }
    ui.ImageFilter filtre;
    final programme = _programme;
    if (programme != null) {
      // La place a l ecran, en pixels, et l echelle des transformations au-dessus.
      final place = MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
      final echelle = size.width > 0 ? place.width / size.width : 1.0;
      final k = _dpr * echelle;
      final shader = _shader ??= programme.fragmentShader();
      // Les deux premiers nombres (la taille du fond) sont donnes par le moteur.
      shader
        ..setFloat(2, place.left * _dpr)
        ..setFloat(3, place.top * _dpr)
        ..setFloat(4, place.width * _dpr)
        ..setFloat(5, place.height * _dpr)
        ..setFloat(6, _rayon * k)
        ..setFloat(7, _biseau * k)
        ..setFloat(8, _force * k)
        ..setFloat(9, _depoli * k)
        ..setFloat(10, _zoom)
        ..setFloat(11, _dispersion * k);
      final lentille = ui.ImageFilter.shader(shader);
      // Le flou d abord, puis la lentille courbe l image floutee au bord.
      filtre = _flou == 0
          ? lentille
          : ui.ImageFilter.compose(
              outer: lentille,
              inner: ui.ImageFilter.blur(sigmaX: _flou, sigmaY: _flou),
            );
    } else {
      // Sans lentille (pas d Impeller, mode leger) : le flou seul.
      filtre = ui.ImageFilter.blur(sigmaX: _flou, sigmaY: _flou);
    }
    final bord = Offset.zero & size;
    _decoupe.layer = context.pushClipRRect(needsCompositing, offset, bord, RRect.fromRectAndRadius(bord, Radius.circular(_rayon)), (context, offset) {
      final couche = _filtre.layer ??= BackdropFilterLayer();
      couche
        ..filter = filtre
        ..backdropKey = _cle;
      context.pushLayer(couche, super.paint, offset);
    }, oldLayer: _decoupe.layer);
  }
}

/// Le verre d iOS pour ce qui se lit ou se remplit (pastille d envoi, champs
/// de saisie) : un depoli elegant mais leger, une masse assez dense pour bien
/// lire, a plat, un filet de lumiere sur le bord, et un bord qui converge un
/// peu, comme une loupe, en irisant a peine.
class VerreLoupe extends StatelessWidget {
  const VerreLoupe({super.key, required this.child, this.rayon = 22, this.padding});

  final Widget child;
  final double rayon;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final nuit = Couleurs.sombre;
    return Lentille(
      rayon: rayon,
      flou: 8,
      biseau: 14,
      force: 6,
      depoli: 0.8,
      dispersion: 0.8,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(rayon), color: nuit ? const Color(0x9E1C1D22) : Colors.white.withValues(alpha: 0.62)),
        child: CustomPaint(
          foregroundPainter: RefletVerre(rayon: rayon, nuit: nuit),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// Le filet de lumiere du verre liquide : vif en haut a gauche, doux en bas a
/// droite (la lumiere vient d en haut).
class RefletVerre extends CustomPainter {
  const RefletVerre({required this.rayon, required this.nuit, this.eclat = 0, this.couleur = false});

  final double rayon;
  final bool nuit;

  /// Sous le doigt (0 a 1) : le filet s eclaire et la masse s illumine un peu.
  final double eclat;

  /// Un verre teinte (bleu, rouge, citron) : un filet plus discret.
  final bool couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final e = eclat.clamp(0.0, 1.0);
    final k = ((nuit ? 0.5 : 1.0) * (couleur ? 0.6 : 1.0) + 0.4 * e).clamp(0.0, 1.0);
    if (e > 0.01) {
      // La lumiere monte dans la masse, du haut, comme sur iOS.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rayon)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.18 * e),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rayon)).deflate(0.55),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 + 0.4 * e
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95 * k),
            Colors.white.withValues(alpha: 0.25 * k),
            Colors.white.withValues(alpha: 0.12 * k),
            Colors.white.withValues(alpha: 0.6 * k),
          ],
          stops: const [0, 0.35, 0.65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(RefletVerre ancien) => ancien.rayon != rayon || ancien.nuit != nuit || ancien.eclat != eclat || ancien.couleur != couleur;
}
