// E11 Carte (repris de usw_mobile) : chaque lieu est un repère en forme de photo
// (un petit triangle de lecture pour les reels). Toucher un repère ouvre son aperçu
// en bas : voir le reel ou le lieu. La position refusée (E37) propose de l'autoriser
// ou de choisir une ville.
// Le fond de carte de usw_mobile demandait les paquets flutter_map et latlong2,
// absents de pubspec.yaml (le socle) : en attendant, un fond uni, où chaque repère
// est placé d'après sa latitude et sa longitude.
// À brancher : GET carte.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/donnees/demo.dart';
import '../../decouverte/widgets/feuille.dart';
import '../../decouverte/widgets/jetons.dart';
import '../../decouverte/widgets/photo.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/demo.dart';

/// Cotonou : la position de démonstration du membre.
const _maPosition = (latitude: 6.3703, longitude: 2.3912);

/// La zone montrée : le Bénin, avec un peu de marge.
const _nord = 11.6, _sud = 5.9, _ouest = 0.9, _est = 3.1;

/// E11 Carte. Voir repartition.md.
class EcranCarte extends StatefulWidget {
  const EcranCarte({super.key});

  @override
  State<EcranCarte> createState() => _EcranCarteState();
}

class _EcranCarteState extends State<EcranCarte> {
  String _filtre = 'Tout';
  Lieu? _choisi;

  // Refusée à l'inscription tant que le membre ne l'autorise pas ici.
  bool _position = false;

  bool _aUnReel(Lieu l) => reelsDemo.any((r) => r.lieu == l.id);

  List<Lieu> get _lieux => switch (_filtre) {
    'Reels' => lieuxDemo.where(_aUnReel).toList(),
    'Photos' => lieuxDemo.where((l) => !_aUnReel(l)).toList(),
    _ => lieuxDemo,
  };

  // Un point de la carte, en pixels dans la zone dessinée.
  Offset _place(double latitude, double longitude, Size zone) =>
      Offset((longitude - _ouest) / (_est - _ouest) * zone.width, (_nord - latitude) / (_nord - _sud) * zone.height);

  // Les repères trop proches (moins de 52 px) se regroupent.
  List<List<Lieu>> _groupes(Size zone) {
    final groupes = <List<Lieu>>[];
    for (final l in _lieux) {
      final ici = _place(l.latitude, l.longitude, zone);
      final proche = groupes.where((g) {
        final la = _place(g.first.latitude, g.first.longitude, zone);
        return (la - ici).distance < 52;
      }).firstOrNull;
      if (proche != null) {
        proche.add(l);
      } else {
        groupes.add([l]);
      }
    }
    return groupes;
  }

  void _choisir(Lieu l) => setState(() => _choisi = l);

  // Sans zoom, un groupe ouvre la liste de ses lieux.
  void _ouvrirGroupe(List<Lieu> g) => montrerFeuille<void>(
    context,
    titre: '${g.length} lieux',
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in g)
            LigneFeuille(
              icone: 'lieu',
              texte: l.nom,
              onTap: () {
                Navigator.pop(f);
                _choisir(l);
              },
            ),
        ],
      ),
    ),
  );

  // E37 position : refusée à l'inscription, on propose de l'autoriser ou de choisir une ville.
  Future<void> _positionDesactivee() => montrerFeuille<void>(
    context,
    titre: 'La position est désactivée',
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pour voir les lieux autour de vous, autorisez la position. Vous pouvez aussi choisir une ville.',
            style: Textes.discret,
          ),
          const SizedBox(height: 18),
          BoutonVerre(
            texte: 'Autoriser la position',
            plein: true,
            onTap: () {
              Navigator.pop(f);
              setState(() => _position = true);
            },
          ),
          const SizedBox(height: 10),
          BoutonVerre(
            texte: 'Choisir une ville',
            onTap: () {
              Navigator.pop(f);
              bulle(context, 'Ville choisie : Cotonou');
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final bas = MediaQuery.paddingOf(context).bottom + 26;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final choisi = _choisi;
    return Scaffold(
      body: Stack(
        children: [
          // La carte : un fond uni, les repères placés d'après leurs coordonnées.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _choisi = null),
              child: ColoredBox(
                color: Teintes.hsl(229, 30, 94),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(marge + 20, haut + 120, marge + 20, bas + 60),
                  child: LayoutBuilder(
                    builder: (context, contraintes) {
                      final zone = contraintes.biggest;
                      final position = _place(_maPosition.latitude, _maPosition.longitude, zone);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final g in _groupes(zone))
                            Positioned(
                              left: _place(g.first.latitude, g.first.longitude, zone).dx - 31,
                              top: _place(g.first.latitude, g.first.longitude, zone).dy - 31,
                              width: 62,
                              height: 62,
                              child: g.length == 1
                                  ? _Repere(
                                      lieu: g.first,
                                      reel: _aUnReel(g.first),
                                      choisi: choisi?.id == g.first.id,
                                      onTap: () => _choisir(g.first),
                                    )
                                  : _Repere(
                                      lieu: g.first,
                                      reel: false,
                                      choisi: false,
                                      nombre: g.length,
                                      onTap: () => _ouvrirGroupe(g),
                                    ),
                            ),
                          // Ma position : un point océan cerclé de blanc.
                          if (_position)
                            Positioned(
                              left: position.dx - 11,
                              top: position.dy - 11,
                              width: 22,
                              height: 22,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Couleurs.ocean,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Le haut : la recherche et les filtres, en verre sur la carte.
          Positioned(
            top: haut + 6,
            left: marge,
            right: marge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Appuyable(
                        semantique: 'Rechercher un lieu',
                        verre: true,
                        rayonVerre: 25,
                        gonflement: 0.03,
                        onTap: () => context.push(Routes.recherche),
                        child: const _Givre(
                          rayon: 25,
                          child: SizedBox(
                            height: 50,
                            child: Row(
                              children: [
                                SizedBox(width: 16),
                                Icone('loupe', taille: 21, couleur: Couleurs.discret),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Rechercher un lieu',
                                    overflow: TextOverflow.ellipsis,
                                    style: Textes.discret,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Appuyable(
                      semantique: 'Filtres',
                      verre: true,
                      rayonVerre: 25,
                      onTap: () => context.push(Routes.recherche),
                      child: const _Givre(
                        rayon: 25,
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(child: Icone('filtres', taille: 22, couleur: Couleurs.texte)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      for (final f in ['Tout', 'Reels', 'Photos', 'Captures vérifiées']) ...[
                        Pastille(texte: f, retenue: _filtre == f, onTap: () => setState(() => _filtre = f)),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Revenir à ma position.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 520),
            curve: CourbesPlus.ressort,
            right: marge,
            bottom: choisi == null ? bas : bas + 168,
            child: Appuyable(
              semantique: 'Ma position',
              verre: true,
              rayonVerre: 25,
              onTap: () => _position ? bulle(context, 'Vous êtes à Cotonou.') : _positionDesactivee(),
              child: const _Givre(
                rayon: 25,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(child: Icone('cible', taille: 23, couleur: Couleurs.texte)),
                ),
              ),
            ),
          ),
          // L'aperçu du repère choisi : il monte du bas, au ressort.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 560),
            curve: CourbesPlus.ressort,
            left: marge,
            right: marge,
            bottom: choisi == null ? -240 : bas,
            child: choisi == null
                ? const SizedBox(height: 150)
                : _Apercu(lieu: choisi, reel: reelsDemo.where((r) => r.lieu == choisi.id).firstOrNull),
          ),
        ],
      ),
    );
  }
}

/// Le verre sur la carte : dépoli léger et blanc.
class _Givre extends StatelessWidget {
  const _Givre({required this.rayon, required this.child});

  final double rayon;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(rayon),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Couleurs.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(rayon),
        ),
        child: Verre(rayon: rayon, surFond: false, ombre: false, child: child),
      ),
    ),
  );
}

class _Repere extends StatelessWidget {
  const _Repere({required this.lieu, required this.reel, required this.choisi, required this.onTap, this.nombre = 1});

  final Lieu lieu;
  final bool reel;
  final bool choisi;
  final VoidCallback onTap;

  /// Un groupe de repères : leur nombre, en pastille.
  final int nombre;

  @override
  Widget build(BuildContext context) => Appuyable(
    semantique: nombre > 1 ? '$nombre lieux' : lieu.nom,
    verre: true,
    gonflement: 0.15,
    onTap: onTap,
    child: Center(
      child: AnimatedScale(
        scale: choisi ? 1.18 : 1,
        duration: const Duration(milliseconds: 420),
        curve: CourbesPlus.ressort,
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: choisi ? Couleurs.texte : Couleurs.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Teintes.hsl(229, 40, 20, 0.28),
                offset: const Offset(0, 4),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              PhotoArrondie(lieu.photos.first, rayon: 11.5),
              if (nombre > 1)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Couleurs.texte,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '$nombre',
                      style: Textes.petit.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              if (reel)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                    child: const Icone('lecture', taille: 10, couleur: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Apercu extends StatelessWidget {
  const _Apercu({required this.lieu, required this.reel});

  final Lieu lieu;
  final Reel? reel;

  // « Y aller » ouvrait l'itinéraire dans Maps avec le paquet url_launcher, absent
  // de pubspec.yaml (le socle). Mis de côté pour le moment :
  //
  // Future<void> _yAller(BuildContext context) async {
  //   final itineraire = Uri.parse(
  //     'https://www.google.com/maps/dir/?api=1&destination=${lieu.latitude},${lieu.longitude}',
  //   );
  //   final ouvert = await launchUrl(itineraire, mode: LaunchMode.externalApplication);
  //   if (!ouvert && context.mounted) bulle(context, "Maps n'a pas pu s'ouvrir.");
  // }

  @override
  Widget build(BuildContext context) {
    final r = reel;
    return _Givre(
      rayon: 26,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              height: 128,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PhotoArrondie(r?.photo ?? lieu.photos.first, rayon: 16),
                  if (r != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${r.duree ~/ 60}:${(r.duree % 60).toString().padLeft(2, '0')}',
                          style: Textes.petit.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lieu.nom,
                    style: Textes.libelle.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icone('telephone', taille: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          r != null ? '${r.appareil} · ${r.pseudo}' : '${lieu.nombre} photos · ${lieu.region}',
                          overflow: TextOverflow.ellipsis,
                          style: Textes.petit.copyWith(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const BadgeCapture(verifie: true, court: true),
                  const SizedBox(height: 10),
                  BoutonVerre(
                    texte: r != null ? 'Voir le reel' : 'Voir le lieu',
                    onTap: () => r != null ? context.go(Routes.reels) : context.push(Routes.lieu(lieu.id)),
                  ),
                  // Le bouton « Y aller », mis de côté avec _yAller ci-dessus : il se plaçait
                  // à droite de « Voir le lieu », dans une ligne.
                  // BoutonVerre(
                  //   texte: lieu.distanceKm != null ? '${lieu.distanceKm} km' : 'Y aller',
                  //   plein: true,
                  //   large: false,
                  //   widgetIcone: const Icone('y-aller', taille: 19),
                  //   onTap: () => _yAller(context),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
