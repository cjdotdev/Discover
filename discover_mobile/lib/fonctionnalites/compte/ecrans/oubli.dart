import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/api/erreur_api.dart';
import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/messages.dart';
import '../../../socle/widgets/page_formulaire.dart';
import '../donnees/depot_compte.dart';

/// E02 Mot de passe oublié : un code part à l'adresse indiquée.
class EcranOubli extends StatefulWidget {
  const EcranOubli({super.key, required this.email});

  final String email;

  @override
  State<EcranOubli> createState() => _EcranOubliState();
}

class _EcranOubliState extends State<EcranOubli> {
  late final _email = TextEditingController(text: widget.email);
  bool _attente = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final adresse = _email.text.trim();
    setState(() => _attente = true);
    try {
      await depotCompte.demanderOubli(adresse);
      if (mounted) context.push(Routes.avec(Routes.code, {'email': adresse, 'but': 'oubli'}));
    } on ErreurApi catch (erreur) {
      if (mounted) bulle(context, erreur.pour('email'));
    } on ApiInjoignable {
      if (mounted) bulle(context, 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFormulaire(
      titre: 'Mot de passe oublié',
      sousTitre: const Text(
        "Indiquez l'e-mail du compte : nous y enverrons un code pour choisir un nouveau mot de passe.",
      ),
      pied: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Vous vous en souvenez ? ', style: Textes.petit),
          Lien('Se connecter', onTap: () => context.pop()),
        ],
      ),
      children: [
        Champ(
          libelle: 'E-mail',
          icone: 'enveloppe',
          indice: 'Adresse e-mail',
          controleur: _email,
          clavier: TextInputType.emailAddress,
          surValidation: (_) => _envoyer(),
        ),
        const SizedBox(height: 16),
        Bouton(texte: 'Envoyer le code', chargement: _attente, onTap: _envoyer),
      ],
    );
  }
}
