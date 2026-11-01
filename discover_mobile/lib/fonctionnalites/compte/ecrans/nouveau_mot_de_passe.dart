import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/api/erreur_api.dart';
import '../../../socle/navigation/routes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/messages.dart';
import '../../../socle/widgets/page_formulaire.dart';
import '../donnees/depot_compte.dart';
import '../donnees/mot_de_passe_regles.dart';
import '../widgets/criteres.dart';

/// E02 Nouveau mot de passe : le serveur vérifie le code reçu à cette étape.
class EcranNouveauMotDePasse extends StatefulWidget {
  const EcranNouveauMotDePasse({super.key, required this.email, required this.code});

  final String email;
  final String code;

  @override
  State<EcranNouveauMotDePasse> createState() => _EcranNouveauMotDePasseState();
}

class _EcranNouveauMotDePasseState extends State<EcranNouveauMotDePasse> {
  String _mot = '';
  String _confirmation = '';
  bool _attente = false;

  bool get _identiques => _mot.isNotEmpty && _mot == _confirmation;

  Future<void> _enregistrer() async {
    setState(() => _attente = true);
    try {
      await depotCompte.nouveauMotDePasse(widget.email, widget.code, _mot);
      if (!mounted) return;
      bulle(context, 'Mot de passe enregistré. Connectez-vous.');
      context.go(Routes.entree);
    } on ErreurApi catch (erreur) {
      if (mounted) bulle(context, erreur.pour('code'));
    } on ApiInjoignable {
      if (mounted) bulle(context, 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFormulaire(
      titre: 'Nouveau mot de passe',
      sousTitre: const Text("Choisissez-en un que vous n'utilisez pas ailleurs."),
      children: [
        Champ(
          libelle: 'Nouveau mot de passe',
          icone: 'cadenas',
          indice: 'Votre mot de passe',
          secret: true,
          autofocus: true,
          surChangement: (valeur) => setState(() => _mot = valeur),
        ),
        const SizedBox(height: 16),
        Champ(
          libelle: 'Confirmer',
          icone: 'cadenas',
          indice: 'Le même mot de passe',
          secret: true,
          surChangement: (valeur) => setState(() => _confirmation = valeur),
        ),
        const SizedBox(height: 14),
        Criteres(
          criteres: [
            ('8 caractères ou plus', ReglesMotDePasse.assezLong(_mot)),
            ('Un chiffre', ReglesMotDePasse.aUnChiffre(_mot)),
            ('Les deux mots de passe sont identiques', _identiques),
          ],
        ),
        const SizedBox(height: 10),
        Bouton(
          texte: 'Enregistrer',
          chargement: _attente,
          onTap: ReglesMotDePasse.valide(_mot) && _identiques ? _enregistrer : null,
        ),
      ],
    );
  }
}
