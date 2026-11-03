import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../donnees/modeles.dart' show videosDesAffiches;
import '../outils/couverture.dart';
import '../outils/images_reseau.dart';
import '../outils/reseau.dart';
import '../outils/videos.dart';
import '../theme/jetons.dart';
import 'icone.dart';

/// L image d une photo : un fichier du telephone (un chemin, « /data/… »),
/// comme une photo qu on vient de prendre, ou une taille servie par Discover
/// (une adresse, gardee ensuite sur le telephone : ImageReseau). Sans l un ni
/// l autre (pas encore de photo), un pixel transparent : le fond reste.
/// [largeur] : la largeur decodee en memoire (1 080 px pour les cartes ; la visionneuse demande
/// celle de l ecran, puis plus au zoom). Nulle : l image entiere.
ImageProvider imageDePhoto(String id, {int? largeur = 1080}) {
  if (id.startsWith('http')) return largeur == null ? ImageReseau(id) : ResizeImage(ImageReseau(id), width: largeur, policy: ResizeImagePolicy.fit);
  if (id.startsWith('/')) return largeur == null ? FileImage(File(id)) : ResizeImage(FileImage(File(id)), width: largeur, policy: ResizeImagePolicy.fit);
  // Une image livree avec l application (les gouts proposes a l inscription).
  if (id.startsWith('assets/')) return AssetImage(id);
  return MemoryImage(_transparent);
}

/// Un PNG de 1 × 1 pixel transparent.
final _transparent = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Une adresse ou un fichier : il y a une vraie photo a montrer.
bool aUnePhoto(String id) => id.startsWith('http') || id.startsWith('/') || id.startsWith('assets/');

class Photo extends StatelessWidget {
  const Photo(this.id, {super.key, this.fit = BoxFit.cover});

  final String id;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => !aUnePhoto(id) ? const PhotoAbsente() : _image(id, fit, 0);
}

Widget _image(String id, BoxFit fit, int essai) => Image(
  image: imageDePhoto(id),
  fit: fit,
  width: double.infinity,
  height: double.infinity,
  gaplessPlayback: true,
  errorBuilder: (context, _, _) => _Reessai(id: id, fit: fit, essai: essai),
);

/// Les delais avant de redemander une image qui n est pas venue (pas encore prete sur le
/// serveur juste apres la publication, reseau coupe) : 4, 15 puis 45 s, au lieu d une case
/// vide jusqu a la relance de Discover.
const _delais = [Duration(seconds: 4), Duration(seconds: 15), Duration(seconds: 45)];

/// La case neutre, puis l image redemandee (_delais).
class _Reessai extends StatefulWidget {
  const _Reessai({required this.id, required this.fit, required this.essai});

  final String id;
  final BoxFit fit;
  final int essai;

  @override
  State<_Reessai> createState() => _ReessaiState();
}

class _ReessaiState extends State<_Reessai> {
  Timer? _minuteur;
  bool _encore = false;

  @override
  void initState() {
    super.initState();
    if (widget.essai < _delais.length) {
      _minuteur = Timer(_delais[widget.essai], () {
        if (mounted) setState(() => _encore = true);
      });
    }
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _encore ? _image(widget.id, widget.fit, widget.essai + 1) : const PhotoAbsente();
}

/// La place d une photo qui n est pas la (un fichier efface, une adresse injoignable, pas
/// encore de photo) : une case neutre et son icone, pour qu on ne croie pas a un trou noir.
class PhotoAbsente extends StatelessWidget {
  const PhotoAbsente({super.key, this.rayon = 0});

  final double rayon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Couleurs.photoVide, borderRadius: rayon == 0 ? null : BorderRadius.circular(rayon)),
    child: LayoutBuilder(
      builder: (context, c) {
        final taille = (c.biggest.shortestSide * 0.32).clamp(14.0, 40.0);
        return Center(
          child: Icone('image', taille: taille, couleur: Couleurs.discret.withValues(alpha: 0.7)),
        );
      },
    ),
  );
}

/// Une photo aux coins arrondis, peinte d un trait : moins cher qu une
/// decoupe (ClipRRect), qui cree un calque.
class PhotoArrondie extends StatefulWidget {
  const PhotoArrondie(this.id, {super.key, this.rayon = Mesures.rayonCarte});

  final String id;
  final double rayon;

  @override
  State<PhotoArrondie> createState() => _PhotoArrondieState();
}

class _PhotoArrondieState extends State<PhotoArrondie> {
  // Pas venue : redemandee plus tard (_delais), par une nouvelle boite qui la recharge.
  int _essai = 0;
  Timer? _minuteur;

  void _echec() {
    if (!mounted || _minuteur != null || _essai >= _delais.length) return;
    _minuteur = Timer(_delais[_essai], () {
      _minuteur = null;
      if (mounted) setState(() => _essai++);
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  // Elle prend toute la place qu on lui donne : sans enfant, une boite
  // decoree ferait zero de large. Le fond reste visible tant que la photo
  // n est pas la (un emplacement qui defile, meme sans image).
  // Dessous, la case neutre et son icone : une photo absente ou illisible la laisse voir.
  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(
      fit: StackFit.expand,
      children: [
        PhotoAbsente(rayon: widget.rayon),
        if (aUnePhoto(widget.id))
          DecoratedBox(
            key: ValueKey(_essai),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.rayon),
              image: DecorationImage(image: imageDePhoto(widget.id), fit: BoxFit.cover, onError: (_, _) => _echec()),
            ),
          ),
      ],
    ),
  );
}

/// Une pile de photos d un lieu : la premiere devant, deux derriere, et
/// toutes les 4 s celle de devant glisse et s efface, la suivante avance.
///
/// Performance : entre deux passages, rien ne bouge et rien ne se redessine
/// (une minuterie attend, l animation ne dure que le passage, 0,7 s). Les
/// photos sont peintes avec leur opacite et leurs coins arrondis par le
/// pinceau (DecorationImage) : ni calque d opacite ni decoupe, qui coutent
/// cher aux telephones modestes. Transform seulement pour le reste.
class Pile extends StatefulWidget {
  const Pile({super.key, required this.photos, this.rayon = Mesures.rayonCarte});

  final List<String> photos;
  final double rayon;

  @override
  State<Pile> createState() => _PileState();
}

class _PileState extends State<Pile> with SingleTickerProviderStateMixin {
  // Un seul metronome pour toutes les piles, qui se relaient : a chaque battement, la moitie des
  // piles a l ecran tourne, en damier (deux en diagonale ensemble, jamais deux voisines cote a
  // cote ou l une sous l autre), l autre moitie au battement suivant. Chaque pile tourne donc
  // toutes les 4 s ; hors de l ecran, elle attend.
  static const _battement = Duration(milliseconds: 2000);
  static final _toutes = <_PileState>{};
  static Timer? _metronome;
  static var _temps = 0;
  bool _actif = true;
  Size _ecran = Size.zero;
  // preserve : avec les animations coupees (economiseur), Flutter abregerait le passage en un saut.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), animationBehavior: AnimationBehavior.preserve);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Courbes.pile);
  int _devant = 0;

  /// Les photos qui n ont pas pu venir : leur carte montre la case neutre, pas un trou noir,
  /// puis elles sont redemandees (_delais).
  final _absentes = <String>{};
  final _essais = <String, int>{};
  final _relances = <Timer>[];

  void _absente(String id) {
    if (!mounted || !_absentes.add(id)) return;
    setState(() {});
    final essai = _essais[id] ?? 0;
    if (essai >= _delais.length) return;
    _essais[id] = essai + 1;
    _relances.add(
      Timer(_delais[essai], () {
        if (mounted) setState(() => _absentes.remove(id));
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _devant++);
        _c.value = 0;
      }
    });
    _toutes.add(this);
    _metronome ??= Timer.periodic(_battement, (_) => _battre());
  }

  // Hors de l ecran (TickerMode coupe : un autre onglet, une page par-dessus) : elle attend. Le
  // mode economiseur ne l arrete pas : un passage toutes les 4 s, sans calque, coute tres peu.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actif = TickerMode.valuesOf(context).enabled;
    _ecran = MediaQuery.sizeOf(context);
  }

  static void _battre() {
    // Une feuille ouverte par-dessus : les piles attendent dessous (son verre reste fluide).
    if (pageCouverte.value > 0) return;
    _temps++;
    // Les colonnes de gauche a droite, puis les rangs de haut en bas dans chaque colonne (une
    // grille en quinconce comme celle de l accueil compris).
    final colonnes = <int, List<(_PileState, Rect)>>{};
    for (final p in _toutes) {
      if (!p.mounted || !p._actif || p.widget.photos.length < 2 || p._c.isAnimating) continue;
      final cadre = p._cadreALEcran();
      if (cadre == null) continue;
      (colonnes[(cadre.left / cadre.width).round()] ??= []).add((p, cadre));
    }
    for (final MapEntry(key: colonne, value: piles) in colonnes.entries) {
      piles.sort((a, b) => a.$2.top.compareTo(b.$2.top));
      for (var rang = 0; rang < piles.length; rang++) {
        if ((colonne + rang + _temps).isEven) piles[rang].$1._c.forward(from: 0);
      }
    }
  }

  /// Sa place a l ecran ; nulle si elle n y est pas.
  Rect? _cadreALEcran() {
    final boite = context.findRenderObject();
    if (boite is! RenderBox || !boite.attached || !boite.hasSize || boite.size.isEmpty) return null;
    final cadre = MatrixUtils.transformRect(boite.getTransformTo(null), Offset.zero & boite.size);
    final vu = cadre.intersect(Offset.zero & _ecran);
    return vu.width > 0 && vu.height > 0 ? cadre : null;
  }

  @override
  void dispose() {
    _toutes.remove(this);
    if (_toutes.isEmpty) {
      _metronome?.cancel();
      _metronome = null;
    }
    for (final r in _relances) {
      r.cancel();
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.photos.length;
    final rayon = BorderRadius.circular(widget.rayon);
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, contraintes) {
          final hauteur = contraintes.maxHeight;
          return AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final t = _t.value;
              // A plat, sans ombre, comme les mosaiques de Pinterest.
              Widget carte(int rang) {
                // Le rang effectif : 0 devant, 1 et 2 derriere, 3 cache ; pendant
                // le passage, tout monte d un rang et celle de devant passe a -1.
                final r = rang - t;
                double opacite, dy, echelle;
                if (r < 0) {
                  // Elle part : elle glisse vers le bas et s efface.
                  opacite = 1 + r;
                  dy = -r * 0.12 * hauteur;
                  echelle = 1 - 0.02 * -r;
                } else if (r <= 1) {
                  opacite = 1 - 0.25 * r;
                  dy = -8 * r;
                  echelle = 1 - 0.07 * r;
                } else if (r <= 2) {
                  opacite = 0.75 - 0.3 * (r - 1);
                  dy = -8 - 7 * (r - 1);
                  echelle = 0.93 - 0.07 * (r - 1);
                } else {
                  opacite = 0.45 * (3 - r);
                  dy = -15;
                  echelle = 0.86;
                }
                // La cle suit la photo : quand elle passe devant, c est la meme
                // carte qui avance, son image reste peinte (pas de clignotement).
                final cle = ValueKey(_devant + rang);
                final photo = (_devant + rang) % n;
                if (opacite <= 0.01) return SizedBox.shrink(key: cle);
                final id = widget.photos[photo];
                final image = DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: rayon,
                    image: DecorationImage(image: imageDePhoto(id), fit: BoxFit.cover, opacity: opacite.clamp(0.0, 1.0), onError: (_, _) => _absente(id)),
                  ),
                );
                // Une video devant : elle se lit sur son affiche, sans le son, en boucle.
                final video = rang == 0 ? videosDesAffiches[id] : null;
                return Transform(
                  key: cle,
                  alignment: Alignment.topCenter,
                  transform: Matrix4.translationValues(0, dy, 0)..scaleByDouble(echelle, echelle, 1, 1),
                  child: !aUnePhoto(id) || _absentes.contains(id)
                      ? Opacity(
                          opacity: opacite.clamp(0.0, 1.0),
                          child: PhotoAbsente(rayon: widget.rayon),
                        )
                      : video == null
                      ? image
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            image,
                            Opacity(
                              opacity: opacite.clamp(0.0, 1.0),
                              child: ClipRRect(
                                borderRadius: rayon,
                                child: VideoMuette(video, key: ValueKey(video)),
                              ),
                            ),
                          ],
                        ),
                );
              }

              return Stack(fit: StackFit.expand, children: [carte(3), carte(2), carte(1), carte(0)]);
            },
          );
        },
      ),
    );
  }
}

/// Une video lue sans le son, en boucle, sur son affiche (piles, grilles, page de la publication,
/// facon Pinterest). Un telephone n a que quelques decodeurs : dans une grille, les 4 videos les
/// plus visibles a l ecran se lisent, pas les premieres construites (une grille construit aussi
/// les cases juste sous l ecran, qui prenaient les places des videos qu on regarde). Hors de
/// l ecran (un autre onglet, une page par-dessus), elle rend son decodeur, et le reprend en
/// revenant (depuis le telephone, aussitot). Tant qu elle n est pas prete, l affiche dessous
/// reste seule. Une case construite pres de l ecran garde deja sa video sur le telephone : elle
/// part aussitot en arrivant a l ecran.
class VideoMuette extends StatefulWidget {
  const VideoMuette(this.source, {super.key, this.prioritaire = false, this.replis = const []});

  /// La video deja lue a l ecran pour cette adresse, confiee au plein ecran : elle continue sans
  /// recharger, comme sur Pinterest. Nulle si aucune n est prete.
  static VideoPlayerController? emprunter(String source) => _VideoMuetteState._emprunter(source);

  /// Le plein ecran se ferme : la video retourne a sa place, toujours en lecture. Faux si sa
  /// place n existe plus (le plein ecran ferme alors le lecteur).
  static bool rendre(String source, VideoPlayerController lecteur) => _VideoMuetteState._rendre(source, lecteur);

  /// Une adresse, ou un fichier du telephone (une video en cours d envoi).
  final String source;

  /// La video principale d une page (la publication ouverte) : elle n attend pas de place.
  final bool prioritaire;

  /// La meme video en plus leger (la 1080p a pour replis la 720p et l apercu) : deja sur le
  /// telephone (vue dans une grille), elle part aussitot au lieu d attendre la 1080p du reseau.
  final List<String> replis;

  @override
  State<VideoMuette> createState() => _VideoMuetteState();
}

class _VideoMuetteState extends State<VideoMuette> {
  /// Les videos d une grille lues en meme temps.
  static const _places = 4;
  static final _toutes = <_VideoMuetteState>{};
  static var _repartitionDemandee = false;

  VideoPlayerController? _lecteur;
  bool _prete = false;
  bool _ouverture = false;

  // Chaque ouverture a son numero : rendue entre-temps, une ouverture en cours s abandonne.
  int _tour = 0;

  // Un rate (le reseau, le serveur) : la place va a une autre video, celle-ci retente apres
  // 4 s, 15 s, puis toutes les 45 s tant qu elle est a l ecran.
  static const _delais = [Duration(seconds: 4), Duration(seconds: 15), Duration(seconds: 45)];
  int _essai = 0;
  Timer? _relance;

  /// TickerMode : coupe pour un autre onglet ou une page par-dessus.
  bool _visible = true;

  /// La part de la video a l ecran, de 0 a 1.
  double _part = 0;
  Size _ecran = Size.zero;
  final _defilements = <ScrollPosition>[];
  bool _mesureDemandee = false;

  /// Confiee au plein ecran : elle ne rouvre pas de lecteur en attendant son retour.
  bool _pretee = false;

  bool get _aUnePlace => _lecteur != null || _ouverture;

  @override
  void initState() {
    super.initState();
    _toutes.add(this);
    _precharger();
    pageCouverte.addListener(_suivreLEcran);
  }

  // Une case d une grille, meme juste sous l ecran : sa video (l apercu, leger) se garde deja sur
  // le telephone. Pas en economie de donnees.
  void _precharger() {
    if (!widget.prioritaire && !Reseau.instance.photosLegeres) unawaited(Videos.instance.prechauffer(widget.source));
  }

  static VideoPlayerController? _emprunter(String source) {
    for (final v in _toutes) {
      final l = v._lecteur;
      if (!v.mounted || v.widget.source != source || !v._prete || l == null) continue;
      v
        .._tour += 1
        .._lecteur = null
        .._prete = false
        .._pretee = true;
      v.setState(() {});
      return l;
    }
    return null;
  }

  static bool _rendre(String source, VideoPlayerController l) {
    for (final v in _toutes) {
      if (!v.mounted || !v._pretee || v.widget.source != source) continue;
      v._liberer();
      v
        .._pretee = false
        .._lecteur = l
        .._prete = true;
      unawaited(l.setVolume(0));
      v.setState(() {});
      v._suivreLEcran();
      v._placer();
      return true;
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _ecran = MediaQuery.sizeOf(context);
    _suivreLesDefilements();
    _mesurer();
    _placer();
    _suivreLEcran();
  }

  @override
  void didUpdateWidget(VideoMuette ancienne) {
    super.didUpdateWidget(ancienne);
    // La case montre une autre video : l ancienne rend sa place.
    if (ancienne.source != widget.source) {
      Videos.instance.renoncer(ancienne.source);
      _precharger();
      _relance?.cancel();
      _relance = null;
      _essai = 0;
      _liberer();
      _placer();
    }
  }

  // Chaque liste qui defile autour (la grille, une rangee dans la grille) : la video se
  // remesure a chaque mouvement.
  void _suivreLesDefilements() {
    for (final p in _defilements) {
      p.removeListener(_mesurer);
    }
    _defilements.clear();
    var s = Scrollable.maybeOf(context);
    while (s != null) {
      _defilements.add(s.position..addListener(_mesurer));
      s = s.context.findAncestorStateOfType<ScrollableState>();
    }
  }

  // Apres le dessin de l image : sa place a l ecran est alors connue.
  void _mesurer() {
    if (_mesureDemandee || !mounted) return;
    _mesureDemandee = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mesureDemandee = false;
      if (!mounted) return;
      final part = _partALEcran();
      if ((part - _part).abs() < 0.05 && (part == 0) == (_part == 0)) return;
      _part = part;
      _demanderRepartition();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  double _partALEcran() {
    final boite = context.findRenderObject();
    if (boite is! RenderBox || !boite.attached || !boite.hasSize || boite.size.isEmpty) return 0;
    final cadre = MatrixUtils.transformRect(boite.getTransformTo(null), Offset.zero & boite.size);
    final vu = cadre.intersect(Offset.zero & _ecran);
    if (vu.width <= 0 || vu.height <= 0 || cadre.isEmpty) return 0;
    return (vu.width * vu.height) / (cadre.width * cadre.height);
  }

  /// La video principale prend sa place d elle-meme ; les autres la recoivent de la repartition.
  void _placer() {
    if (!widget.prioritaire) return _demanderRepartition();
    _visible && _relance == null ? _demarrer() : _liberer();
  }

  static void _demanderRepartition() {
    if (_repartitionDemandee) return;
    _repartitionDemandee = true;
    scheduleMicrotask(_repartir);
  }

  // Les plus visibles d abord ; une video deja lue garde sa place face a une a peine plus
  // visible (pas de va-et-vient pendant le defilement). Elles demarrent une a une : la suivante
  // attend que la precedente soit lancee (3 s au plus), le telephone et le reseau ne recoivent
  // jamais tout d un coup.
  static void _repartir() {
    _repartitionDemandee = false;
    double score(_VideoMuetteState v) => v._part + (v._aUnePlace ? 0.15 : 0);
    final elues =
        (_toutes.where((v) => v.mounted && !v.widget.prioritaire && v._visible && v._relance == null && v._part >= (v._aUnePlace ? 0.05 : 0.2)).toList()..sort((a, b) => score(b).compareTo(score(a))))
            .take(_places)
            .toSet();
    // Les decodeurs se rendent avant d etre repris.
    for (final v in _toutes.toList()) {
      if (!v.widget.prioritaire && !elues.contains(v)) v._liberer();
    }
    final maintenant = DateTime.now();
    if (_toutes.any((v) => !v.widget.prioritaire && v._ouverture && maintenant.difference(v._ouverteLe) < _uneAUne)) return;
    for (final v in elues) {
      if (v._aUnePlace || v._pretee) continue;
      v._demarrer();
      // Toujours en route apres 3 s (un reseau lent) : la suivante n attend plus.
      Timer(_uneAUne, _demanderRepartition);
      return;
    }
  }

  static const _uneAUne = Duration(seconds: 3);
  DateTime _ouverteLe = DateTime(0);

  void _demarrer() {
    if (_aUnePlace || _pretee || !mounted) return;
    _ouvrir();
  }

  Future<void> _ouvrir() async {
    final tour = ++_tour;
    _ouverture = true;
    _ouverteLe = DateTime.now();
    VideoPlayerController? l;
    try {
      // Depuis le telephone si elle y est deja (aussitot), sinon en continu.
      l = await Videos.instance.lecteur(widget.source, replis: widget.replis, options: VideoPlayerOptions(mixWithOthers: true));
      if (tour != _tour) {
        unawaited(l.dispose());
        return;
      }
      _lecteur = l;
      await l.setVolume(0);
      await l.setLooping(true);
      await l.initialize();
      // Rendue pendant l ouverture : _liberer a deja ferme le lecteur.
      if (tour != _tour || !mounted) return;
      _ouverture = false;
      _essai = 0;
      setState(() => _prete = true);
      _suivreLEcran();
      // Lancee : au tour de la suivante, un instant apres.
      if (!widget.prioritaire) Timer(const Duration(milliseconds: 250), _demanderRepartition);
    } catch (_) {
      if (tour != _tour) return;
      // L affiche reste ; la place va a une autre video, celle-ci retente plus tard.
      _ouverture = false;
      _lecteur = null;
      unawaited(l?.dispose());
      if (!mounted) return;
      _relance = Timer(_delais[_essai < _delais.length ? _essai : _delais.length - 1], () {
        _relance = null;
        if (mounted) _placer();
      });
      _essai++;
      _placer();
    }
  }

  // En pause sous une feuille ouverte (le fond de son verre ne bouge plus), et hors de l ecran.
  void _suivreLEcran() {
    final l = _lecteur;
    if (l == null || !_prete) return;
    _visible && pageCouverte.value == 0 ? l.play() : l.pause();
  }

  /// Rend le decodeur : une autre video peut le prendre.
  void _liberer() {
    if (!_aUnePlace) return;
    _tour++;
    _ouverture = false;
    final l = _lecteur;
    _lecteur = null;
    final etaitPrete = _prete;
    _prete = false;
    unawaited(l?.dispose());
    if (etaitPrete && mounted) setState(() {});
  }

  @override
  void dispose() {
    _toutes.remove(this);
    pageCouverte.removeListener(_suivreLEcran);
    Videos.instance.renoncer(widget.source);
    _relance?.cancel();
    for (final p in _defilements) {
      p.removeListener(_mesurer);
    }
    _tour++;
    _lecteur?.dispose();
    _demanderRepartition();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lecteur;
    if (l == null || !_prete) return const SizedBox.expand();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: l.value.size.width, height: l.value.size.height, child: VideoPlayer(l)),
    );
  }
}
