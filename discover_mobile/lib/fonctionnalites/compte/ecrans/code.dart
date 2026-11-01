import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/api/erreur_api.dart';
import '../../../socle/navigation/routes.dart';
import '../../../socle/session/session.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/messages.dart';
import '../../../socle/widgets/page_formulaire.dart';
import '../donnees/depot_compte.dart';
import '../widgets/champ_code.dart';

/// E02 Code reçu par e-mail. À l'inscription, il ouvre la session ; quand le mot de passe
/// est oublié (`oubli`), il suit vers le nouveau mot de passe, où le serveur le vérifie.
class EcranCode extends StatefulWidget {
  const EcranCode({super.key, required this.email, this.oubli = false});

  final String email;
  final bool oubli;

  @override
  State<EcranCode> createState() => _EcranCodeState();
}

class _EcranCodeState extends State<EcranCode> {
  static const _delaiRenvoi = 60;

  Timer? _minuteur;
  int _secondes = _delaiRenvoi;
  String _code = '';
  String? _erreur;
  bool _attente = false;

  @override
  void initState() {
    super.initState();
    _demarrerMinuteur();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  void _demarrerMinuteur() {
    _secondes = _delaiRenvoi;
    _minuteur = Timer.periodic(const Duration(seconds: 1), (minuteur) {
      setState(() => _secondes--);
      if (_secondes == 0) minuteur.cancel();
    });
  }

  Future<void> _renvoyer() async {
    try {
      await depotCompte.renvoyerCode(widget.email);
      if (!mounted) return;
      setState(_demarrerMinuteur);
      bulle(context, 'Un nouveau code est parti.');
    } on ApiInjoignable {
      if (mounted) bulle(context, 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    }
  }

  Future<void> _verifier() async {
    if (widget.oubli) {
      context.push(Routes.avec(Routes.nouveauMotDePasse, {'email': widget.email, 'code': _code}));
      return;
    }
    setState(() {
      _attente = true;
      _erreur = null;
    });
    try {
      await depotCompte.verifierCode(widget.email, _code);
      if (mounted) context.go(Session.instance.destination);
    } on ErreurApi catch (erreur) {
      if (mounted) setState(() => _erreur = erreur.pour('code'));
    } on ApiInjoignable {
      if (mounted) setState(() => _erreur = 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attente = '0:${_secondes.toString().padLeft(2, '0')}';
    return PageFormulaire(
      titre: 'Vérifiez votre e-mail',
      sousTitre: Text('Nous avons envoyé un code à 6 chiffres à ${widget.email}.'),
      pied: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Mauvaise adresse ? ', style: Textes.petit),
          Lien('La corriger', onTap: () => context.pop()),
        ],
      ),
      children: [
        ChampCode(
          erreur: _erreur != null,
          surChangement: (valeur) => setState(() {
            _code = valeur;
            _erreur = null;
          }),
        ),
        const SizedBox(height: 10),
        if (_erreur != null)
          Text(
            _erreur!,
            style: Textes.petit.copyWith(color: Couleurs.erreur),
            textAlign: TextAlign.center,
          ),
        Center(
          child: _secondes > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Renvoyer le code dans $attente', style: Textes.petit),
                )
              : Lien('Renvoyer le code', onTap: _renvoyer),
        ),
        const SizedBox(height: 6),
        Bouton(texte: 'Vérifier', chargement: _attente, onTap: _code.length == 6 ? _verifier : null),
      ],
    );
  }
}
