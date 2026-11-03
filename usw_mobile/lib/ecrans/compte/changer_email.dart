// Modifier l adresse e-mail d un compte. Trois verrous : celui du telephone (empreinte, code
// ou schema) avant d ouvrir cet ecran, un code envoye a la nouvelle adresse pour prouver
// qu elle est a vous, et une alerte envoyee a l ancienne. Un compte Google garde l adresse
// de Google : cet ecran ne s ouvre pas pour lui.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../donnees/session.dart';
import '../../outils/api.dart';
import '../../outils/langue.dart';
import '../../theme/jetons.dart';
import '../../theme/theme.dart';
import '../../widgets/champ.dart';
import '../../widgets/icone.dart';
import '../../widgets/page.dart';
import '../../widgets/verre.dart';

/// Le verrou du telephone, puis l ecran. Sans verrou d ecran sur le telephone, on le dit.
Future<void> ouvrirChangerEmail(BuildContext context) async {
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) {
      if (context.mounted) bulle(context, t('Pour modifier votre adresse, configurez d’abord le verrouillage de l’écran de ce téléphone.'), icone: 'cadenas');
      return;
    }
    if (!await auth.authenticate(localizedReason: t('Confirmez qu’il s’agit bien de vous'), biometricOnly: false)) return;
  } catch (_) {
    if (context.mounted) bulle(context, t('Impossible de vérifier votre identité sur ce téléphone.'), icone: 'cadenas');
    return;
  }
  if (context.mounted) unawaited(context.push('/profil/acces/adresse'));
}

// La phrase traduite, l adresse en gras a la place de {email}.
List<(String, bool)> _avecAdresse(String phrase, String adresse) {
  final i = phrase.indexOf('{email}');
  if (i < 0) return [(phrase, false)];
  return [(phrase.substring(0, i), false), (adresse, true), (phrase.substring(i + 7), false)];
}

class EcranChangerEmail extends StatefulWidget {
  const EcranChangerEmail({super.key});

  @override
  State<EcranChangerEmail> createState() => _EcranChangerEmailState();
}

class _EcranChangerEmailState extends State<EcranChangerEmail> {
  final _adresse = TextEditingController();
  String? _envoyeeA;
  String _code = '';
  String? _erreur;
  bool _attente = false;
  int _reste = 0;
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    _adresse.dispose();
    super.dispose();
  }

  void _decompte() {
    _minuteur?.cancel();
    _reste = 59;
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _reste--);
      if (_reste <= 0) t.cancel();
    });
  }

  Future<void> _envoyer() async {
    final adresse = _adresse.text.trim().toLowerCase();
    if (_attente || adresse.isEmpty) return;
    setState(() {
      _attente = true;
      _erreur = null;
    });
    try {
      await Session.instance.demanderChangementEmail(adresse);
      if (!mounted) return;
      setState(() {
        _envoyeeA = adresse;
        _code = '';
      });
      _decompte();
    } on ErreurApi catch (e) {
      if (mounted) setState(() => _erreur = e.pour('email'));
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  Future<void> _confirmer() async {
    if (_attente || _code.length != 6) return;
    setState(() {
      _attente = true;
      _erreur = null;
    });
    try {
      await Session.instance.confirmerChangementEmail(_code);
      if (!mounted) return;
      bulle(context, t('Adresse e-mail mise à jour.'), icone: 'enveloppe');
      context.pop();
    } on ErreurApi catch (e) {
      if (mounted) setState(() => _erreur = e.pour('code'));
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  Widget _messageErreur() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icone('alerte', taille: 15, couleur: Couleurs.erreur),
        const SizedBox(width: 6),
        Flexible(
          child: Text(_erreur!, style: Textes.petit.copyWith(color: Couleurs.erreur)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final envoyee = _envoyeeA;
    if (envoyee == null) {
      return PageFormulaire(
        enfants: [
          Titre(t('Nouvelle adresse e-mail'), style: Textes.titre, centre: true),
          const SizedBox(height: 10),
          TextePage(_avecAdresse(t('Un code de validation sera envoyé à cette adresse. Votre adresse actuelle, {email}, recevra une notification.'), Session.instance.email), centre: true),
          const SizedBox(height: 26),
          ChampVerre(
            icone: 'enveloppe',
            indice: t('nom@exemple.com'),
            controleur: _adresse,
            clavier: TextInputType.emailAddress,
            action: TextInputAction.send,
            autofocus: true,
            onChanged: (_) => setState(() => _erreur = null),
            onSubmitted: (_) => _envoyer(),
          ),
          if (_erreur != null) _messageErreur(),
          const SizedBox(height: 22),
          BoutonVerre(texte: t('Envoyer le code'), plein: true, onTap: _attente ? null : _envoyer),
        ],
      );
    }
    return PageFormulaire(
      enfants: [
        Titre(t('Validez votre nouvelle adresse'), style: Textes.titre, centre: true),
        const SizedBox(height: 10),
        TextePage(_avecAdresse(t('Saisissez le code à 6 chiffres envoyé à {email}.'), envoyee), centre: true),
        const SizedBox(height: 26),
        ChampCode(
          onChanged: (v) => setState(() {
            _code = v;
            _erreur = null;
          }),
          onComplet: (_) => _confirmer(),
        ),
        if (_erreur != null) _messageErreur(),
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
              : Lien(t('Renvoyer le code'), onTap: _envoyer),
        ),
        const SizedBox(height: 22),
        BoutonVerre(texte: t('Valider'), plein: true, onTap: _code.length == 6 && !_attente ? _confirmer : null),
      ],
      pied: PiedLien(question: t('Mauvaise adresse ?'), lien: t('La modifier'), onTap: () => setState(() => _envoyeeA = null)),
    );
  }
}
