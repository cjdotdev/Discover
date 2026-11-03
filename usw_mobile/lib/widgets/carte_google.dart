// La carte de Google (Maps SDK, gratuit sans limite sur mobile) : celle du
// telephone, avec ses ecoles, ses commerces, ses quartiers. La nuit, un style
// bleu nuit, comme Google Maps en mode sombre. La cle vient de cles.json :
// Gradle la pose dans le manifeste (android/app/build.gradle.kts).
// Sous les tests, pas de carte native : un fond uni.
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../outils/images_reseau.dart';
import '../theme/jetons.dart';

export 'package:google_maps_flutter/google_maps_flutter.dart' show BitmapDescriptor, CameraPosition, CameraUpdate, GoogleMapController, LatLng, Marker, MarkerId;

final _sousTest = Platform.environment.containsKey('FLUTTER_TEST');

/// La nuit : le fond bleu nuit, les routes bleu-gris, l eau plus sombre, les
/// noms en gris clair. Les icones des lieux (ecoles, sante, commerces) restent.
const _styleNuit = '''[
  {"elementType": "geometry", "stylers": [{"color": "#1d2a3d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#a7b4c8"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1d2a3d"}]},
  {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#3a4a63"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d3dceb"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry", "stylers": [{"color": "#223147"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#223147"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#1c3a3a"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#33476a"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1d2a3d"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9fb0c9"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#3d5480"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#5571a3"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#d3dceb"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2a3a55"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f1a2b"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#5d6f8c"}]}
]''';

/// La carte, ou un fond uni sous les tests. `padding` : ce que l ecran pose
/// dessus (le logo de Google et ma position restent visibles au-dessus).
/// La carte native met un instant a dessiner sa premiere image : un fond uni
/// la couvre jusque-la, puis s efface (plus de petit ecran qui clignote).
class CarteGoogle extends StatefulWidget {
  const CarteGoogle({
    super.key,
    required this.centre,
    required this.zoom,
    this.reperes = const {},
    this.maPosition = false,
    this.padding = EdgeInsets.zero,
    this.onCree,
    this.onBouge,
    this.onDebut,
    this.onArret,
    this.onTap,
  });

  final LatLng centre;
  final double zoom;
  final Set<Marker> reperes;
  final bool maPosition;
  final EdgeInsets padding;
  final void Function(GoogleMapController)? onCree;
  final void Function(CameraPosition)? onBouge;
  final VoidCallback? onDebut;
  final VoidCallback? onArret;
  final VoidCallback? onTap;

  @override
  State<CarteGoogle> createState() => _CarteGoogleState();
}

class _CarteGoogleState extends State<CarteGoogle> {
  bool _dessinee = false;

  void _cree(GoogleMapController c) {
    widget.onCree?.call(c);
    // La premiere image des tuiles arrive juste apres : le voile s efface alors.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _dessinee = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sousTest) return SizedBox.expand(child: ColoredBox(color: Couleurs.fond));
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          // Le style change avec le theme : la carte se recree, sa camera aussi.
          key: ValueKey(Couleurs.sombre),
          initialCameraPosition: CameraPosition(target: widget.centre, zoom: widget.zoom),
          style: Couleurs.sombre ? _styleNuit : null,
          markers: widget.reperes,
          myLocationEnabled: widget.maPosition,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          padding: widget.padding,
          onMapCreated: _cree,
          onCameraMove: widget.onBouge,
          onCameraMoveStarted: widget.onDebut,
          onCameraIdle: widget.onArret,
          onTap: widget.onTap == null ? null : (_) => widget.onTap!(),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _dessinee ? 0 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: ColoredBox(color: Couleurs.fond),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ les reperes en photo

final _icones = <String, Future<BitmapDescriptor>>{};

/// Le repere d un lieu : sa photo dans un carre arrondi a filet ; un triangle
/// de lecture pour un reel ; le nombre de lieux pour un groupe. Choisi, il
/// grandit et son cadre passe a l encre. Dessine une fois, puis garde.
Future<BitmapDescriptor> iconeRepere({required String photo, required double dpr, int nombre = 1, bool reel = false, bool choisi = false}) {
  final cle = '$photo|$nombre|$reel|$choisi|$dpr|${Couleurs.sombre}';
  return _icones[cle] ??= _dessiner(photo, dpr, nombre, reel, choisi).catchError((Object _) {
    _icones.remove(cle);
    return BitmapDescriptor.defaultMarker;
  });
}

Future<BitmapDescriptor> _dessiner(String photo, double dpr, int nombre, bool reel, bool choisi) async {
  const marge = 10.0;
  final cote = choisi ? 56.0 : 48.0;
  final total = cote + 2 * marge;
  final enregistreur = ui.PictureRecorder();
  final c = Canvas(enregistreur)..scale(dpr);
  final cadre = RRect.fromRectAndRadius(Rect.fromLTWH(marge, marge, cote, cote), const Radius.circular(14));

  c.drawRRect(cadre, Paint()..color = choisi ? Couleurs.texte : Couleurs.surface);
  c.drawRRect(
    cadre,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Couleurs.hsl(229, 30, 20, 0.18),
  );

  final dedans = cadre.deflate(2.5);
  final image = await _image(photo, (cote * dpr).round());
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(dedans.outerRect, const Radius.circular(11.5)));
  if (image != null) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final cible = dedans.outerRect;
    // La photo remplit le carre (comme BoxFit.cover).
    final ratio = cible.width / cible.height;
    final srcAjuste = src.width / src.height > ratio
        ? Rect.fromCenter(center: src.center, width: src.height * ratio, height: src.height)
        : Rect.fromCenter(center: src.center, width: src.width, height: src.width / ratio);
    c.drawImageRect(image, srcAjuste, cible, Paint()..filterQuality = FilterQuality.medium);
  } else {
    c.drawRect(dedans.outerRect, Paint()..color = Couleurs.photoVide);
  }
  c.restore();

  if (reel) {
    final centre = Offset(marge + cote - 11, marge + cote - 11);
    c.drawCircle(centre, 8, Paint()..color = Colors.black.withValues(alpha: 0.55));
    c.drawPath(
      Path()
        ..moveTo(centre.dx - 2.5, centre.dy - 4)
        ..lineTo(centre.dx + 4, centre.dy)
        ..lineTo(centre.dx - 2.5, centre.dy + 4)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  if (nombre > 1) {
    final texte = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 12.5, fontWeight: FontWeight.w700))
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText('$nombre');
    final p = texte.build()..layout(const ui.ParagraphConstraints(width: 40));
    final largeur = (p.longestLine + 12).clamp(22.0, 40.0);
    final pastille = RRect.fromRectAndRadius(Rect.fromLTWH(marge + cote - largeur + 8, marge - 8, largeur, 22), const Radius.circular(11));
    // Bleu plein et liseré blanc, de jour comme de nuit : en couleur de texte, la pastille
    // devenait gris clair la nuit, sous un chiffre blanc (illisible).
    c.drawRRect(pastille, Paint()..color = Colors.white);
    c.drawRRect(pastille.deflate(2), Paint()..color = Couleurs.ocean);
    c.drawParagraph(p, Offset(pastille.center.dx - 20, pastille.center.dy - p.height / 2));
  }

  final dessin = await enregistreur.endRecording().toImage((total * dpr).round(), (total * dpr).round());
  final octets = await dessin.toByteData(format: ui.ImageByteFormat.png);
  dessin.dispose();
  image?.dispose();
  return BytesMapBitmap(octets!.buffer.asUint8List(), imagePixelRatio: dpr);
}

/// La photo d un lieu (une adresse, gardee par ImagesReseau, ou un fichier du telephone).
Future<ui.Image?> _image(String photo, int largeur) async {
  try {
    final Uint8List octets;
    if (photo.startsWith('http')) {
      octets = await ImagesReseau.octets(photo);
    } else if (photo.isNotEmpty && File(photo).existsSync()) {
      octets = await File(photo).readAsBytes();
    } else {
      return null;
    }
    final codec = await ui.instantiateImageCodec(octets, targetWidth: largeur);
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}
