// E30 Indiquer le lieu (repris de usw_mobile) : l'épingle au centre, le lieu connu le
// plus proche et ses coordonnées, puis « Choisir ce lieu », qui le renvoie à l'étape
// d'avant. Dans usw_mobile, on déplaçait la carte sous l'épingle ; la carte demande les
// paquets flutter_map et latlong2, absents de pubspec.yaml (le socle) : en attendant,
// un fond uni, et on choisit le lieu dans la liste.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../decouverte/donnees/demo.dart';
import '../../decouverte/widgets/jetons.dart';
import '../../decouverte/widgets/verre.dart';

/// E30 Indiquer le lieu. Voir repartition.md.
class EcranIndiquerLieu extends StatefulWidget {
  const EcranIndiquerLieu({super.key});

  @override
  State<EcranIndiquerLieu> createState() => _EcranIndiquerLieuState();
}

class _EcranIndiquerLieuState extends State<EcranIndiquerLieu> {
  ({double latitude, double longitude}) _centre = (latitude: 6.2795, longitude: 1.8226);

  // Le lieu connu le plus proche du centre, ou le point lui-même.
  (String, String) get _choix {
    Lieu? proche;
    var mieux = 0.05;
    for (final l in lieuxDemo) {
      final d = (l.latitude - _centre.latitude).abs() + (l.longitude - _centre.longitude).abs();
      if (d < mieux) {
        mieux = d;
        proche = l;
      }
    }
    String c(double v, String p, String m) => '${v.abs().toStringAsFixed(4).replaceAll('.', ',')}° ${v >= 0 ? p : m}';
    final gps = '${c(_centre.latitude, 'N', 'S')}, ${c(_centre.longitude, 'E', 'O')}';
    return proche == null ? ('Point choisi', gps) : (proche.nom, '${proche.region} · $gps');
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final bas = MediaQuery.paddingOf(context).bottom;
    final (nom, detail) = _choix;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Teintes.hsl(229, 30, 94))),
          // L'épingle reste au centre.
          const IgnorePointer(
            child: Center(
              child: FractionalTranslation(translation: Offset(0, -0.5), child: Icone('epingle', taille: 46)),
            ),
          ),
          Positioned(
            top: haut + 8,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RondVerre(
                      icone: 'retour',
                      semantique: 'Retour',
                      onTap: () => context.canPop() ? context.pop() : context.go(Routes.creer),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Verre(
                        rayon: 25,
                        child: SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const Icone('loupe', taille: 21, couleur: Couleurs.discret),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  nom,
                                  overflow: TextOverflow.ellipsis,
                                  style: Textes.corps.copyWith(fontSize: 15.5),
                                ),
                              ),
                            ],
                          ),
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
                      for (final l in lieuxDemo) ...[
                        Pastille(
                          texte: l.nom,
                          retenue: nom == l.nom,
                          onTap: () => setState(() => _centre = (latitude: l.latitude, longitude: l.longitude)),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: bas + 14,
            child: Verre(
              rayon: 26,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Choisissez un lieu pour poser l'épingle.", style: Textes.petit),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icone('lieu', taille: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nom, style: Textes.libelle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(detail, style: Textes.petit.copyWith(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BoutonVerre(
                    texte: 'Choisir ce lieu',
                    plein: true,
                    onTap: () => context.pop(nom == 'Point choisi' ? detail : nom),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
