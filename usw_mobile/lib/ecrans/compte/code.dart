// E02, la suite de l entree : le code a 6 chiffres recu par e-mail. Pas de mot
// de passe dans Discover : le code ouvre le compte, ou le cree s il n existait
// pas. Aucune page ne montre le nom ni la photo du compte avant la connexion :
// ce serait dire a n importe qui qu une adresse est inscrite.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../donnees/capture.dart';
import '../../donnees/session.dart';
import '../../outils/api.dart';
import '../../outils/langue.dart';
import '../../theme/jetons.dart';
import '../../theme/theme.dart';
import '../../widgets/champ.dart';
import '../../widgets/icone.dart';
import '../../widgets/mouvement.dart';
import '../../widgets/page.dart';
import '../../widgets/verre.dart';

const _delaiForm = Duration(milliseconds: 400);

/// Ce que le serveur renvoie a la connexion : on entre (profil a completer, ou l accueil).
Future<void> _entrer(BuildContext context, Reponse r) async {
  final s = Session.instance;
  await s.ouvrir(r);
  if (context.mounted) context.go(s.profilComplete ? '/accueil' : '/completer/1');
}

/// Pas de reseau au milieu du parcours : on le dit, l ecran reste tel quel.
void _horsLigne(BuildContext context) => bulle(context, t('Impossible de joindre le serveur. Réessayez dans un instant.'), icone: 'hors-ligne');

// La phrase traduite, l adresse en gras a la place de {email}.
List<(String, bool)> _avecAdresse(String phrase, String adresse) {
  final i = phrase.indexOf('{email}');
  if (i < 0) return [(phrase, false)];
  return [(phrase.substring(0, i), false), (adresse, true), (phrase.substring(i + 7), false)];
}

class EcranCode extends StatefulWidget {
  const EcranCode({super.key});

  @override
  State<EcranCode> createState() => _EcranCodeState();
}

class _EcranCodeState extends State<EcranCode> {
  String _code = '';
  int _reste = 59;
  Timer? _minuteur;
  String? _erreur;
  bool _attente = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  void _demarrer() {
    _minuteur?.cancel();
    _reste = 59;
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _reste--);
      if (_reste <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _verifier() async {
    final s = Session.instance;
    if (_attente) return;
    setState(() {
      _attente = true;
      _erreur = null;
    });
    try {
      final r = await s.verifierCode(_code, appareil: await modeleDuTelephone());
      if (!mounted) return;
      await _entrer(context, r);
    } on ErreurApi catch (e) {
      if (mounted) setState(() => _erreur = e.pour('code'));
    } on ApiInjoignable {
      if (mounted) _horsLigne(context);
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  Future<void> _renvoyer() async {
    _demarrer();
    final s = Session.instance;
    try {
      await s.demanderCode(s.email);
    } on ErreurApi catch (e) {
      if (mounted) e.code == 0 ? _horsLigne(context) : bulle(context, e.message, icone: 'alerte');
      return;
    }
    if (mounted) bulle(context, t('Nouveau code envoyé.'));
  }

  @override
  Widget build(BuildContext context) => PageFormulaire(
    enfants: [
      Titre(t('Vérifiez votre e-mail'), style: Textes.titre, centre: true),
      const SizedBox(height: 10),
      Monte(delai: const Duration(milliseconds: 300), child: TextePage(_avecAdresse(t('Nous avons envoyé un code à 6 chiffres à {email}.'), Session.instance.email), centre: true)),
      const SizedBox(height: 26),
      Monte(
        delai: _delaiForm,
        child: ChampCode(
          onChanged: (v) => setState(() {
            _code = v;
            _erreur = null;
          }),
          onComplet: (_) => _verifier(),
        ),
      ),
      if (_erreur != null) ...[
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icone('alerte', taille: 15, couleur: Couleurs.erreur),
            const SizedBox(width: 6),
            Flexible(
              child: Text(_erreur!, style: Textes.petit.copyWith(color: Couleurs.erreur)),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      Center(
        child: _reste > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icone('horloge', taille: 15, couleur: Couleurs.discret),
                  const SizedBox(width: 6),
                  Text(t('Renvoyer le code dans {temps}', {'temps': '0:${_reste.toString().padLeft(2, '0')}'}), style: Textes.petit),
                ],
              )
            : Lien(t('Renvoyer le code'), onTap: _renvoyer),
      ),
      const SizedBox(height: 22),
      BoutonVerre(texte: t('Vérifier'), plein: true, onTap: _code.length == 6 && !_attente ? _verifier : null),
    ],
    pied: PiedLien(question: t('Mauvaise adresse ?'), lien: t('La corriger'), onTap: () => context.go('/entree')),
  );
}
