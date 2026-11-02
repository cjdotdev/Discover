// E15 Compléter (repris de usw_mobile) : ce que le fichier ne dit pas. Une photo
// ancienne sans téléphone ni date : le membre les indique, avec le lieu, et elle
// sera publiée avec le badge « Informations déclarées ».
// À brancher : GET et POST modeles-telephone.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart' show Lien;
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/icone.dart';
import '../../decouverte/widgets/verre.dart';
import '../widgets/page_etape.dart';
import '../widgets/plaque.dart';

/// E15 Compléter. Voir repartition.md.
class EcranCompleterCapture extends StatefulWidget {
  const EcranCompleterCapture({super.key});

  @override
  State<EcranCompleterCapture> createState() => _EcranCompleterCaptureState();
}

class _EcranCompleterCaptureState extends State<EcranCompleterCapture> {
  final _modele = TextEditingController();
  final _date = TextEditingController();
  String? _telephone;
  String? _lieu;

  static const _connus = [
    'Tecno Spark 30 Pro',
    'Tecno Spark 20C',
    'Tecno Camon 50 Pro',
    'Infinix Note 40',
    'Samsung Galaxy A15',
    'iPhone 12',
  ];

  @override
  void dispose() {
    _modele.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saisie = _modele.text.trim();
    final proches = saisie.length < 2
        ? const <String>[]
        : _connus.where((m) => m.toLowerCase().contains(saisie.toLowerCase())).take(3).toList();
    final pret = _telephone != null && _date.text.trim().isNotEmpty;
    return PageEtape(
      pied: BoutonVerre(texte: 'Continuer', plein: true, onTap: pret ? () => context.push(Routes.details) : null),
      enfants: [
        const SizedBox(height: 10),
        Semantics(header: true, child: const Text('Ce que le fichier ne dit pas', style: Textes.titre)),
        const SizedBox(height: 10),
        const Text(
          'Cette photo ancienne n’a ni téléphone ni date. Indiquez-les : elle sera publiée avec le badge '
          '« Informations déclarées ».',
          style: Textes.discret,
        ),
        const SizedBox(height: 22),
        Champ(
          libelle: "Le téléphone qui l'a prise",
          icone: 'telephone',
          indice: 'Tapez le modèle',
          controleur: _modele,
          surChangement: (_) => setState(() => _telephone = null),
        ),
        const SizedBox(height: 6),
        const Text("Choisissez-le s'il est dans la liste, sinon ajoutez-le.", style: Textes.petit),
        if (_telephone == null && saisie.length >= 2) ...[
          const SizedBox(height: 8),
          Plaque(
            rayon: 18,
            child: Column(
              children: [
                if (!_connus.any((m) => m.toLowerCase() == saisie.toLowerCase()))
                  ListTile(
                    leading: const Icone('plus', taille: 22, couleur: Couleurs.texte),
                    title: Text('Ajouter « $saisie »', style: Textes.libelle),
                    subtitle: const Text('Il rejoindra la liste pour les suivants', style: Textes.petit),
                    onTap: () => setState(() => _telephone = saisie),
                  ),
                for (final m in proches)
                  ListTile(
                    leading: const Icone('telephone', taille: 22),
                    title: Text(m, style: Textes.corps),
                    subtitle: const Text('Déjà utilisé sur Discover', style: Textes.petit),
                    onTap: () => setState(() {
                      _telephone = m;
                      _modele.text = m;
                    }),
                  ),
              ],
            ),
          ),
        ],
        if (_telephone == null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Lien(
              "C'est ce téléphone : Tecno Camon 50 Pro",
              onTap: () => setState(() {
                _telephone = 'Tecno Camon 50 Pro';
                _modele.text = _telephone!;
              }),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Champ(
          libelle: 'La date de la prise',
          icone: 'calendrier',
          indice: 'Mars 2019',
          controleur: _date,
          surChangement: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        const Text("Le mois et l'année suffisent.", style: Textes.petit),
        const SizedBox(height: 16),
        const Text('Le lieu', style: Textes.libelle),
        const SizedBox(height: 8),
        Appuyable(
          semantique: 'Indiquer le lieu',
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
                    Icone('lieu', taille: 22, couleur: _lieu == null ? Couleurs.discret : null),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lieu ?? 'Pas de GPS dans le fichier',
                        overflow: TextOverflow.ellipsis,
                        style: Textes.corps.copyWith(
                          fontSize: 16,
                          color: _lieu == null ? Couleurs.discret : Couleurs.texte,
                        ),
                      ),
                    ),
                    Text(_lieu == null ? 'Indiquer' : 'Changer', style: Textes.lien.copyWith(color: Couleurs.texte)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Badge de la publication', style: Textes.petit),
            BadgeCapture(verifie: false),
          ],
        ),
      ],
    );
  }
}
