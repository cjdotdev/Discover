// E14 Détails (repris de usw_mobile) : l'aperçu avec son badge, ce que le fichier
// dit (téléphone, date, lieu), la légende, le lieu trouvé et son type. « Publier »
// lance l'envoi et mène à E16.
// À brancher : POST contenus.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/widgets/photo.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/envois.dart';
import '../widgets/page_etape.dart';

/// E14 Détails. Voir repartition.md.
class EcranDetails extends StatefulWidget {
  const EcranDetails({super.key});

  @override
  State<EcranDetails> createState() => _EcranDetailsState();
}

class _EcranDetailsState extends State<EcranDetails> {
  final _legende = TextEditingController(text: 'Les pirogues rentrent au coucher du soleil, côté Possotomé.');
  String _lieu = 'Lac Ahémé, Possotomé, Mono';
  final _types = <String>{'Lac et lagune'};

  // Importée (E15) : les informations sont déclarées. Prise avec l'appareil : vérifiées.
  final bool _declaree = Brouillon.instance.declaree;

  @override
  void dispose() {
    _legende.dispose();
    super.dispose();
  }

  String get _photo => _declaree ? 'p57' : 'p124';

  void _publier() {
    Envois.instance.publier(titre: _lieu.split(',').first, photo: _photo, poidsMo: 6.4);
    context.go(Routes.enRoute);
    bulle(context, 'Publication lancée : vous pouvez continuer à naviguer.');
  }

  @override
  Widget build(BuildContext context) => PageEtape(
    titre: 'Nouvelle publication',
    pied: BoutonVerre(texte: 'Publier', icone: 'envoyer', plein: true, onTap: _publier),
    enfants: [
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoArrondie(_photo, rayon: 16),
                Positioned(left: 7, bottom: 7, child: BadgeCapture(verifie: !_declaree, seul: true)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgeCapture(verifie: !_declaree, court: true),
                const SizedBox(height: 12),
                for (final (icone, texte) in [
                  ('telephone', _declaree ? 'Tecno Spark 30C' : 'Tecno Camon 50 Pro'),
                  ('calendrier', _declaree ? 'Mars 2019' : '12 août 2026'),
                  ('lieu', _lieu.split(',').first),
                ]) ...[
                  Row(
                    children: [
                      Icone(icone, taille: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(texte, style: Textes.corps.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Champ(
        libelle: 'Légende',
        icone: 'crayon',
        indice: 'Ce qu’on voit, comment y aller',
        controleur: _legende,
        lignes: 3,
      ),
      const SizedBox(height: 16),
      const Text('Lieu trouvé', style: Textes.libelle),
      const SizedBox(height: 8),
      Appuyable(
        semantique: 'Changer le lieu',
        onTap: () async {
          final l = await context.push<String>(Routes.indiquerLieu);
          if (l != null) setState(() => _lieu = l);
        },
        child: Verre(
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icone('lieu', taille: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_lieu, overflow: TextOverflow.ellipsis, style: Textes.corps.copyWith(fontSize: 16)),
                  ),
                  const Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in ['Lac et lagune', 'Plage', 'Village', 'Nature'])
            Pastille(
              texte: t,
              retenue: _types.contains(t),
              onTap: () => setState(() => _types.contains(t) ? _types.remove(t) : _types.add(t)),
            ),
        ],
      ),
    ],
  );
}
