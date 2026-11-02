// E04 Filtres (repris de usw_mobile, où ils vivaient dans recherche.dart) : pays,
// types de lieux, distance, tri, captures vérifiées. La recherche (E31) les ouvre
// en feuille ; l'adresse /filtres les montre en page.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../donnees/demo.dart';
import '../widgets/verre.dart';

/// Les filtres retenus : ils restent d'une recherche à l'autre.
class Filtres {
  Filtres._();
  static final instance = Filtres._();

  String pays = 'Bénin';
  final types = <String>{};
  int? distanceKm;
  bool verifiees = false;
  String tri = 'Pertinence';

  int get actifs => types.length + (distanceKm != null ? 1 : 0) + (verifiees ? 1 : 0) + (tri != 'Pertinence' ? 1 : 0);

  void effacer() {
    types.clear();
    distanceKm = null;
    verifiees = false;
    tri = 'Pertinence';
  }
}

/// E04 Filtres, en page. Voir repartition.md.
class EcranFiltres extends StatelessWidget {
  const EcranFiltres({super.key});

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(marge, 8, marge, 12),
              child: Row(
                children: [
                  RondVerre(
                    icone: 'retour',
                    semantique: 'Retour',
                    onTap: () => context.canPop() ? context.pop() : context.go(Routes.recherche),
                  ),
                  const SizedBox(width: 12),
                  const Text('Filtres', style: Textes.sousTitre),
                ],
              ),
            ),
            Expanded(child: ContenuFiltres(onChange: () {})),
          ],
        ),
      ),
    );
  }
}

/// Le contenu des filtres : dans la feuille de la recherche, ou dans la page.
class ContenuFiltres extends StatefulWidget {
  const ContenuFiltres({super.key, required this.onChange});

  final VoidCallback onChange;

  @override
  State<ContenuFiltres> createState() => _ContenuFiltresState();
}

class _ContenuFiltresState extends State<ContenuFiltres> {
  final f = Filtres.instance;

  void _changer(VoidCallback c) {
    setState(c);
    widget.onChange();
  }

  Widget _groupe(String titre, List<Widget> pastilles) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: Textes.libelle.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: pastilles),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final types = {for (final l in lieuxDemo) l.type}.toList();
    final nombre = lieuxDemo
        .where(
          (l) =>
              (f.types.isEmpty || f.types.contains(l.type)) &&
              (f.distanceKm == null || (l.distanceKm ?? 99999) <= f.distanceKm!),
        )
        .length;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        _groupe('Pays', [
          for (final p in ['Bénin', 'Togo', 'Ghana', 'Nigeria'])
            Pastille(texte: p, retenue: f.pays == p, onTap: () => _changer(() => f.pays = p)),
        ]),
        _groupe('Types de lieux', [
          for (final t in types)
            Pastille(
              texte: t,
              retenue: f.types.contains(t),
              onTap: () => _changer(() => f.types.contains(t) ? f.types.remove(t) : f.types.add(t)),
            ),
        ]),
        _groupe('Distance', [
          for (final (nom, km) in const [('Partout', null), ('10 km', 10), ('50 km', 50), ('100 km', 100)])
            Pastille(texte: nom, retenue: f.distanceKm == km, onTap: () => _changer(() => f.distanceKm = km)),
        ]),
        _groupe('Trier', [
          for (final t in ['Pertinence', 'Près de moi', 'Récents'])
            Pastille(texte: t, retenue: f.tri == t, onTap: () => _changer(() => f.tri = t)),
        ]),
        Row(
          children: [
            const Expanded(child: Text('Seulement les captures vérifiées', style: Textes.libelle)),
            Switch(
              value: f.verifiees,
              activeTrackColor: Couleurs.ocean,
              onChanged: (v) => _changer(() => f.verifiees = v),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(
              onPressed: () => _changer(f.effacer),
              child: Text('Tout effacer', style: Textes.libelle.copyWith(fontSize: 15)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BoutonVerre(
                texte: 'Voir $nombre ${nombre > 1 ? 'lieux' : 'lieu'}',
                plein: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
