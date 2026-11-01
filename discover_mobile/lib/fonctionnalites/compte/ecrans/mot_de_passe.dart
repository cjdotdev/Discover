import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/api/erreur_api.dart';
import '../../../socle/navigation/routes.dart';
import '../../../socle/session/session.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/page_formulaire.dart';
import '../donnees/depot_compte.dart';
import '../widgets/pastille_email.dart';

/// E02 Mot de passe, et son erreur (E37). Ni nom ni photo : on ne révèle pas qui est inscrit.
class EcranMotDePasse extends StatefulWidget {
  const EcranMotDePasse({super.key, required this.email});

  final String email;

  @override
  State<EcranMotDePasse> createState() => _EcranMotDePasseState();
}

class _EcranMotDePasseState extends State<EcranMotDePasse> {
  final _motDePasse = TextEditingController();
  String? _erreur;
  bool _attente = false;

  @override
  void dispose() {
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    setState(() {
      _attente = true;
      _erreur = null;
    });
    try {
      await depotCompte.connexion(widget.email, _motDePasse.text);
      if (mounted) context.go(Session.instance.destination);
    } on ErreurApi catch (erreur) {
      if (mounted) setState(() => _erreur = erreur.pour('mot_de_passe'));
    } on ApiInjoignable {
      if (mounted) setState(() => _erreur = 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFormulaire(
      entete: PastilleEmail(email: widget.email),
      titre: 'Entrez votre mot de passe',
      children: [
        Champ(
          libelle: 'Mot de passe',
          icone: 'cadenas',
          indice: 'Votre mot de passe',
          controleur: _motDePasse,
          secret: true,
          autofocus: true,
          erreur: _erreur,
          surValidation: (_) => _seConnecter(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Lien(
            'Mot de passe oublié ?',
            onTap: () => context.push(Routes.avec(Routes.oubli, {'email': widget.email})),
          ),
        ),
        const SizedBox(height: 6),
        Bouton(texte: 'Se connecter', chargement: _attente, onTap: _seConnecter),
      ],
    );
  }
}
