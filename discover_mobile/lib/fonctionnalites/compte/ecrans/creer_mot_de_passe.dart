import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/api/erreur_api.dart';
import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/messages.dart';
import '../../../socle/widgets/page_formulaire.dart';
import '../donnees/depot_compte.dart';
import '../donnees/mot_de_passe_regles.dart';
import '../widgets/criteres.dart';

/// E02 Créer le mot de passe : les règles se cochent pendant la saisie.
class EcranCreerMotDePasse extends StatefulWidget {
  const EcranCreerMotDePasse({super.key, required this.email});

  final String email;

  @override
  State<EcranCreerMotDePasse> createState() => _EcranCreerMotDePasseState();
}

class _EcranCreerMotDePasseState extends State<EcranCreerMotDePasse> {
  String _mot = '';
  bool _attente = false;

  Future<void> _continuer() async {
    setState(() => _attente = true);
    try {
      await depotCompte.inscription(widget.email, _mot);
      if (mounted) context.push(Routes.avec(Routes.code, {'email': widget.email}));
    } on ErreurApi catch (erreur) {
      if (mounted) bulle(context, erreur.pour('mot_de_passe'));
    } on ApiInjoignable {
      if (mounted) bulle(context, 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regles = [
      ('8 caractères ou plus', ReglesMotDePasse.assezLong(_mot)),
      ('Un chiffre', ReglesMotDePasse.aUnChiffre(_mot)),
      ('Une lettre', ReglesMotDePasse.aUneLettre(_mot)),
    ];
    final remplies = regles.where((regle) => regle.$2).length;
    return PageFormulaire(
      titre: 'Créez votre mot de passe',
      sousTitre: Text('Pour le compte ${widget.email}.'),
      pied: const Text(
        'En continuant, vous acceptez les conditions générales de Discover '
        'et reconnaissez avoir lu la politique de confidentialité.',
        style: Textes.petit,
        textAlign: TextAlign.center,
      ),
      children: [
        Champ(
          libelle: 'Mot de passe',
          icone: 'cadenas',
          indice: 'Votre mot de passe',
          secret: true,
          autofocus: true,
          surChangement: (valeur) => setState(() => _mot = valeur),
        ),
        const SizedBox(height: 10),
        _Force(remplies: remplies, total: regles.length),
        const SizedBox(height: 14),
        Criteres(criteres: regles),
        const SizedBox(height: 10),
        Bouton(texte: 'Continuer', chargement: _attente, onTap: ReglesMotDePasse.valide(_mot) ? _continuer : null),
      ],
    );
  }
}

// La barre de force du mot de passe, sous le champ.
class _Force extends StatelessWidget {
  const _Force({required this.remplies, required this.total});

  final int remplies;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 32,
            height: 3,
            margin: const EdgeInsets.only(right: 4),
            color: i < remplies ? Couleurs.ocean : Couleurs.texte.withValues(alpha: 0.1),
          ),
        const SizedBox(width: 6),
        Text(remplies == total ? 'Solide' : 'Trop faible', style: Textes.petit),
      ],
    );
  }
}
