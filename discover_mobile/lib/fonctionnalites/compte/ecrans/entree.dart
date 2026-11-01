import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/api/erreur_api.dart';
import '../../../socle/navigation/routes.dart';
import '../../../socle/session/session.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../donnees/depot_compte.dart';

/// E02 Entrée, comme Pinterest : l'e-mail d'abord, ou Google. Le serveur dit seulement
/// si l'adresse existe : on passe alors au mot de passe, ou à sa création.
class EcranEntree extends StatefulWidget {
  const EcranEntree({super.key});

  @override
  State<EcranEntree> createState() => _EcranEntreeState();
}

class _EcranEntreeState extends State<EcranEntree> {
  static final _formeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _email = TextEditingController();
  String? _erreur;
  bool _attente = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    final adresse = _email.text.trim();
    if (!_formeEmail.hasMatch(adresse)) {
      setState(
        () => _erreur = adresse.isEmpty ? 'Saisissez votre adresse e-mail.' : 'Saisissez une adresse e-mail valide.',
      );
      return;
    }
    await _agir(() async {
      final existe = await depotCompte.emailExiste(adresse);
      if (!mounted) return;
      context.push(Routes.avec(existe ? Routes.motDePasse : Routes.creerMotDePasse, {'email': adresse}));
    });
  }

  Future<void> _google() => _agir(() async {
    await depotCompte.connexionGoogle();
    if (mounted) context.go(Session.instance.destination);
  });

  Future<void> _agir(Future<void> Function() action) async {
    setState(() {
      _attente = true;
      _erreur = null;
    });
    try {
      await action();
    } on ErreurApi catch (erreur) {
      if (mounted) bulle(context, erreur.message);
    } on ApiInjoignable {
      if (mounted) bulle(context, 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: Stack(
        children: [
          const _Mosaique(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, contraintes) => SingleChildScrollView(
                reverse: true,
                padding: EdgeInsets.fromLTRB(marge, 0, marge, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contraintes.maxHeight - 16),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Mesures.largeurFormulaire),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Logo()),
                          const SizedBox(height: 14),
                          const Text('Bienvenue sur Discover', style: Textes.titre, textAlign: TextAlign.center),
                          const SizedBox(height: 22),
                          Champ(
                            libelle: 'E-mail',
                            icone: 'enveloppe',
                            indice: 'Adresse e-mail',
                            controleur: _email,
                            clavier: TextInputType.emailAddress,
                            action: TextInputAction.go,
                            erreur: _erreur,
                            surChangement: (_) {
                              if (_erreur != null) setState(() => _erreur = null);
                            },
                            surValidation: (_) => _continuer(),
                          ),
                          const SizedBox(height: 16),
                          Bouton(texte: 'Continuer', chargement: _attente, onTap: _continuer),
                          const SizedBox(height: 16),
                          const _SeparateurOu(),
                          const SizedBox(height: 16),
                          Bouton(
                            texte: 'Continuer avec Google',
                            principal: false,
                            icone: const Icone('google', taille: 20),
                            onTap: _attente ? null : _google,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'En continuant, vous acceptez les conditions générales de Discover '
                            'et reconnaissez avoir lu la politique de confidentialité.',
                            style: Textes.petit,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Les photos du haut, en trois colonnes décalées, qui s'effacent vers le formulaire.
class _Mosaique extends StatelessWidget {
  const _Mosaique();

  static const _colonnes = [
    ['couchers', 'cascades'],
    ['mer', 'paysages'],
    ['nature', 'ville'],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.42,
      width: double.infinity,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.6, 1],
        ).createShader(rect),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _colonnes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: i == 1 ? 0 : 24),
                      child: Column(children: [for (final image in _colonnes[i]) _Vignette(image: image)]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Mesures.rayonCarte),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Image.asset('assets/images/$image.webp', fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _SeparateurOu extends StatelessWidget {
  const _SeparateurOu();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Couleurs.texte.withValues(alpha: 0.1))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('ou', style: Textes.petit),
        ),
        Expanded(child: Divider(color: Couleurs.texte.withValues(alpha: 0.1))),
      ],
    );
  }
}
