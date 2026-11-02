// E20 Profil d'un créateur (repris de usw_mobile, où il vivait dans profil.dart) :
// sa tête, s'abonner, ses publications et ses reels, et ses options en feuille.
// À brancher : GET utilisateurs/{nom}, utilisateurs/{nom}/contenus et
// PUT / DELETE utilisateurs/{nom}/abonnement.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../donnees/demo.dart';
import '../widgets/avatar.dart';
import '../widgets/feuille.dart';
import '../widgets/jetons.dart';
import '../widgets/mosaique.dart';
import '../widgets/onglets.dart';
import '../widgets/verre.dart';

String _nombre(int n) => n < 1000 ? '$n' : '${n ~/ 1000} ${(n % 1000).toString().padLeft(3, '0')}';

void _publication(BuildContext context, RefPublication r) => context.push(Routes.photo('${r.$1}-${r.$2}'));

/// E20 Profil d'un créateur. Voir repartition.md.
class EcranCreateur extends StatefulWidget {
  const EcranCreateur({super.key, required this.nom});

  final String nom;

  @override
  State<EcranCreateur> createState() => _EcranCreateurState();
}

class _EcranCreateurState extends State<EcranCreateur> {
  bool _abonne = false;
  int _onglet = 0;

  void _options(Createur c) => montrerFeuille<void>(
    context,
    titre: c.nom,
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LigneFeuille(icone: 'partager', texte: 'Partager le profil', onTap: () => Navigator.pop(f)),
          LigneFeuille(
            icone: 'lien',
            texte: 'Copier le lien',
            onTap: () {
              Navigator.pop(f);
              bulle(context, 'Le lien du profil est copié.');
            },
          ),
          LigneFeuille(
            icone: 'bloque',
            texte: 'Bloquer ${c.nom}',
            danger: true,
            onTap: () {
              Navigator.pop(f);
              bulle(context, '${c.nom} est bloqué : vous ne verrez plus ses publications.');
            },
          ),
          // Signaler (E22) est hors du MVP : la feuille de signalement de usw_mobile n'est pas reprise.
          LigneFeuille(icone: 'drapeau', texte: 'Signaler le profil', danger: true, onTap: () => Navigator.pop(f)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = createurDe(widget.nom);
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final refs = _onglet == 0 ? c.refs : c.refs.where((r) => publicationDe(r).reel).toList();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, haut + 8, 0, hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: marge),
            child: Row(
              children: [
                RondVerre(
                  icone: 'retour',
                  semantique: 'Retour',
                  onTap: () => context.canPop() ? context.pop() : context.go(Routes.accueil),
                ),
                const Spacer(),
                RondVerre(
                  icone: 'partager',
                  semantique: 'Partager le profil',
                  onTap: () => bulle(context, 'Le lien du profil est copié.'),
                ),
                const SizedBox(width: 6),
                RondVerre(icone: 'plus-points', semantique: "Plus d'options", onTap: () => _options(c)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 6, marge, 14),
            child: _Tete(
              nom: c.nom,
              pseudo: c.pseudo,
              bio: c.bio,
              ville: c.ville,
              abonnes: c.abonnes + (_abonne ? 1 : 0),
            ),
          ),
          Center(
            child: BoutonVerre(
              texte: _abonne ? 'Abonné' : "S'abonner",
              plein: !_abonne,
              large: false,
              onTap: () => setState(() => _abonne = !_abonne),
            ),
          ),
          const SizedBox(height: 18),
          OngletsTexte(
            noms: const ['Publications', 'Reels'],
            actif: _onglet,
            onChange: (i) => setState(() => _onglet = i),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: MosaiquePublications(
              publications: [for (final r in refs) publicationDe(r)],
              titre: (i) => lieuDe(refs[i].$1).nom,
              onTap: (i) => _publication(context, refs[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// La tête d'un profil.
class _Tete extends StatelessWidget {
  const _Tete({required this.nom, required this.pseudo, required this.bio, required this.ville, required this.abonnes});

  final String nom;
  final String pseudo;
  final String bio;
  final String ville;
  final int abonnes;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Avatar(nom: nom, taille: 104),
      const SizedBox(height: 14),
      Semantics(
        header: true,
        child: Text(
          nom,
          textAlign: TextAlign.center,
          style: Textes.titre.copyWith(fontSize: 26, letterSpacing: -0.6, height: 1.2),
        ),
      ),
      const SizedBox(height: 2),
      Text('@$pseudo', style: Textes.petit.copyWith(fontSize: 14.5)),
      if (bio.isNotEmpty) ...[const SizedBox(height: 10), Text(bio, textAlign: TextAlign.center, style: Textes.corps)],
      const SizedBox(height: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icone('lieu', taille: 16),
          const SizedBox(width: 4),
          Text(ville, style: Textes.libelle.copyWith(fontSize: 14, color: Couleurs.discret)),
        ],
      ),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: _nombre(abonnes),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' abonnés'),
          ],
        ),
        style: Textes.corps.copyWith(fontSize: 14),
      ),
    ],
  );
}
