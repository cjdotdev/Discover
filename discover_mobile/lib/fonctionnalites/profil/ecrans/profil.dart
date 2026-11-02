// E18 Mon profil (repris de usw_mobile) : la tête du profil (avatar, nom, bio, ville,
// abonnés), puis mes publications, mes reels et mes enregistrements.
// À brancher : GET moi et GET moi/contenus.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/donnees/demo.dart';
import '../../decouverte/widgets/avatar.dart';
import '../../decouverte/widgets/jetons.dart';
import '../../decouverte/widgets/mosaique.dart';
import '../../decouverte/widgets/onglets.dart';
import '../../decouverte/widgets/photo.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/demo.dart';
import '../donnees/mon_profil.dart';

String _nombre(int n) => n < 1000 ? '$n' : '${n ~/ 1000} ${(n % 1000).toString().padLeft(3, '0')}';

void _publication(BuildContext context, RefPublication r) => context.push(Routes.photo('${r.$1}-${r.$2}'));

/// E18 Mon profil. Voir repartition.md.
class EcranProfil extends StatefulWidget {
  const EcranProfil({super.key});

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final refs = switch (_onglet) {
      0 => mesPublications,
      1 => mesPublications.where((r) => publicationDe(r).reel).toList(),
      _ => const <RefPublication>[],
    };
    return Scaffold(
      body: ListenableBuilder(
        listenable: MonProfil.instance,
        builder: (context, _) {
          final p = MonProfil.instance;
          return ListView(
            padding: EdgeInsets.fromLTRB(0, haut + 8, 0, hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: marge),
                child: Row(
                  children: [
                    RondVerre(
                      icone: 'partager',
                      semantique: 'Partager le profil',
                      onTap: () => bulle(context, 'Le lien de votre profil est copié.'),
                    ),
                    const Spacer(),
                    RondVerre(
                      icone: 'telecharger',
                      semantique: 'Mes envois',
                      onTap: () => context.push(Routes.enRoute),
                    ),
                    const SizedBox(width: 6),
                    RondVerre(icone: 'reglages', semantique: 'Réglages', onTap: () => context.push(Routes.reglages)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(marge, 6, marge, 18),
                child: _Tete(
                  nom: p.nomAffiche,
                  pseudo: p.nomUtilisateur,
                  bio: p.bio,
                  ville: '${p.ville}, ${p.pays}',
                  abonnes: 1284,
                  abonnements: 312,
                ),
              ),
              OngletsTexte(
                noms: const ['Publications', 'Reels', 'Enregistrés'],
                actif: _onglet,
                onChange: (i) => setState(() => _onglet = i),
              ),
              const SizedBox(height: 12),
              if (_onglet == 2)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: marge),
                  child: const _Collections(),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: MosaiquePublications(
                    publications: [for (final r in refs) publicationDe(r)],
                    titre: (i) => lieuDe(refs[i].$1).nom,
                    onTap: (i) => _publication(context, refs[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// La tête d'un profil.
class _Tete extends StatelessWidget {
  const _Tete({
    required this.nom,
    required this.pseudo,
    required this.bio,
    required this.ville,
    required this.abonnes,
    required this.abonnements,
  });

  final String nom;
  final String pseudo;
  final String bio;
  final String ville;
  final int abonnes;
  final int abonnements;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Avatar(nom: nom.isEmpty ? 'U' : nom, taille: 104),
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
            const TextSpan(text: ' abonnés  ·  '),
            TextSpan(
              text: _nombre(abonnements),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' abonnements'),
          ],
        ),
        style: Textes.corps.copyWith(fontSize: 14),
      ),
    ],
  );
}

/// Les collections : une grande photo et deux petites, comme les tableaux de Pinterest.
/// Ouvrir une collection (E19) est hors du MVP.
class _Collections extends StatelessWidget {
  const _Collections();

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 16,
    crossAxisSpacing: 10,
    childAspectRatio: 0.92,
    children: [
      for (final c in collectionsDemo)
        Appuyable(
          semantique: c.nom,
          onTap: () => bulle(context, 'Les collections arrivent bientôt.'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Couverture(c)),
              const SizedBox(height: 8),
              Text(c.nom, style: Textes.libelle.copyWith(fontSize: 15)),
              Row(
                children: [
                  if (c.secrete) ...[
                    const Icone('cadenas', taille: 14, couleur: Couleurs.discret),
                    const SizedBox(width: 3),
                  ],
                  Text('${c.nombre} publications', style: Textes.petit.copyWith(fontSize: 12.5)),
                ],
              ),
            ],
          ),
        ),
    ],
  );
}

/// La couverture d'une collection : sa première photo en grand, deux autres à côté.
class _Couverture extends StatelessWidget {
  const _Couverture(this.collection);

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final refs = collection.refs;
    Widget photo(int n) => Photo(publicationDe(refs[n % refs.length]).photo);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: photo(0)),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: photo(1)),
                const SizedBox(height: 2),
                Expanded(child: photo(2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
