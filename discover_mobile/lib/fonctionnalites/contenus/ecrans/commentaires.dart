// E07 Commentaires (repris de la feuille des commentaires de usw_mobile, ici en page) :
// le commentaire épinglé de l'auteur, les autres, aimer et répondre, et en bas le
// champ pour écrire. La photo (E05) et les reels (E06) y mènent.
// À brancher : GET et POST contenus/{contenu}/commentaires.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/icone.dart';
import '../../decouverte/widgets/avatar.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/demo.dart';
import '../widgets/texte_mentions.dart';

class _Avis {
  const _Avis(this.nom, this.texte, this.quand, this.aime, {this.auteur = false, this.epingle = false});
  final String nom;
  final String texte;
  final String quand;
  final int aime;
  final bool auteur;
  final bool epingle;
}

/// E07 Commentaires. Voir repartition.md.
class EcranCommentaires extends StatefulWidget {
  const EcranCommentaires({super.key, required this.id});

  final String id;

  @override
  State<EcranCommentaires> createState() => _EcranCommentairesState();
}

class _EcranCommentairesState extends State<EcranCommentaires> {
  final _saisie = TextEditingController();
  late final _infos = infosCommentaires(widget.id);
  late final _avis = <_Avis>[
    _Avis(
      _infos.auteur,
      'Le sentier part derrière le campement, 20 min de marche. Prenez des sandales qui tiennent.',
      '1 j',
      412,
      auteur: true,
      epingle: true,
    ),
    const _Avis('Akouavi K.', 'Le passage à 0:12 😍 On y va en janvier avec @mawuli.s.', '6 h', 38),
    const _Avis('Edem A.', "C'est accessible en saison des pluies ?", '3 h', 4),
    const _Avis('Fifamè H.', "J'y étais en mars, l'eau était encore là. Magnifique.", '2 h', 12),
  ];
  final _aimes = <int>{};

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  void _envoyer() {
    final t = _saisie.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _avis.insert(1, _Avis('Vous', t, 'maintenant', 0));
      _saisie.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final nombre = _infos.nombre + _avis.length - 4;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(marge, 8, marge, 8),
              child: Row(
                children: [
                  RondVerre(
                    icone: 'retour',
                    semantique: 'Retour',
                    onTap: () => context.canPop() ? context.pop() : context.go(Routes.accueil),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(header: true, child: Text('$nombre commentaires', style: Textes.sousTitre)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(marge + 4, 8, marge, 8),
                itemCount: _avis.length,
                itemBuilder: (context, i) {
                  final a = _avis[i];
                  final aime = _aimes.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(nom: a.nom, taille: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (a.epingle)
                                Text(
                                  "Épinglé par l'auteur",
                                  style: Textes.petit.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              Row(
                                children: [
                                  Text(
                                    a.nom,
                                    style: Textes.libelle.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                  if (a.auteur) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Couleurs.texte.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('Auteur', style: Textes.libelle.copyWith(fontSize: 11)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              TexteMentions(a.texte),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(a.quand, style: Textes.petit.copyWith(fontSize: 12.5)),
                                  const SizedBox(width: 14),
                                  GestureDetector(
                                    onTap: () => _saisie.text =
                                        '@${a.nom.toLowerCase().replaceAll(' ', '.').replaceAll('..', '.')} ',
                                    child: Text(
                                      'Répondre',
                                      style: Textes.petit.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => aime ? _aimes.remove(i) : _aimes.add(i)),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Column(
                              children: [
                                Icone(
                                  aime ? 'coeur-plein' : 'coeur',
                                  taille: 18,
                                  couleur: aime ? Couleurs.erreur : Couleurs.discret,
                                ),
                                Text('${a.aime + (aime ? 1 : 0)}', style: Textes.petit.copyWith(fontSize: 11.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(marge, 4, marge, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Champ(
                      icone: 'commentaire',
                      indice: 'Ajouter un commentaire, @mentionner…',
                      controleur: _saisie,
                      action: TextInputAction.send,
                      surValidation: (_) => _envoyer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RondVerre(icone: 'envoyer', semantique: 'Envoyer', onTap: _envoyer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
