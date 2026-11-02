// E21 Modifier le profil (repris de usw_mobile) : nom affiché, nom d'utilisateur,
// bio (160 caractères au plus) et site web, visibles par tous.
// À brancher : PATCH moi et POST moi/avatar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/widgets/avatar.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/mon_profil.dart';

/// E21 Modifier le profil. Voir repartition.md.
class EcranModifierProfil extends StatefulWidget {
  const EcranModifierProfil({super.key});

  @override
  State<EcranModifierProfil> createState() => _EcranModifierProfilState();
}

class _EcranModifierProfilState extends State<EcranModifierProfil> {
  final p = MonProfil.instance;
  late final _nom = TextEditingController(text: p.nomAffiche);
  late final _pseudo = TextEditingController(text: p.nomUtilisateur);
  late final _bio = TextEditingController(text: p.bio);
  late final _site = TextEditingController(text: p.site);

  @override
  void dispose() {
    for (final c in [_nom, _pseudo, _bio, _site]) {
      c.dispose();
    }
    super.dispose();
  }

  void _terminer() {
    if (_bio.text.length > 160) return;
    p.enregistrer(
      nomAffiche: _nom.text.trim(),
      nomUtilisateur: _pseudo.text.trim(),
      bio: _bio.text.trim(),
      site: _site.text.trim(),
    );
    bulle(context, 'Votre profil est enregistré.');
    context.canPop() ? context.pop() : context.go(Routes.profil);
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              RondVerre(
                icone: 'retour',
                semantique: 'Retour',
                onTap: () => context.canPop() ? context.pop() : context.go(Routes.profil),
              ),
              Expanded(
                child: Text(
                  'Modifier le profil',
                  textAlign: TextAlign.center,
                  style: Textes.libelle.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              BoutonVerre(texte: 'Terminé', plein: true, large: false, onTap: _terminer),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Ces informations sont visibles par tous, à côté de vos photos.',
            style: Textes.discret,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ValueListenableBuilder(
                  valueListenable: _nom,
                  builder: (context, v, _) => Avatar(nom: v.text.isEmpty ? 'U' : v.text, taille: 104),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: RondVerre(
                    icone: 'camera',
                    semantique: 'Changer la photo',
                    taille: 40,
                    onTap: () => bulle(context, 'Le choix de la photo arrive bientôt.'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Champ(libelle: 'Nom affiché', icone: 'profil', indice: 'Votre nom', controleur: _nom),
          const SizedBox(height: 16),
          Champ(libelle: "Nom d'utilisateur", icone: 'arobase', indice: 'nom.utilisateur', controleur: _pseudo),
          const SizedBox(height: 16),
          ValueListenableBuilder(
            valueListenable: _bio,
            builder: (context, v, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Champ(
                  libelle: 'Bio',
                  icone: 'crayon',
                  indice: 'Ce que vous photographiez',
                  controleur: _bio,
                  lignes: 3,
                  erreur: v.text.length > 160 ? '160 caractères au plus.' : null,
                ),
                const SizedBox(height: 6),
                Text('${v.text.length} sur 160 caractères', style: Textes.petit),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Champ(
            libelle: 'Site web (facultatif)',
            icone: 'lien',
            indice: 'monsite.com',
            controleur: _site,
            clavier: TextInputType.url,
          ),
        ],
      ),
    );
  }
}
