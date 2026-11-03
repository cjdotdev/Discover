// E02 Entree, facon Pinterest : une mosaique de photos qui glisse, l e-mail
// puis « Continuer », ou « Continuer avec Google ». Pas de mot de passe : un
// code a 6 chiffres part a l adresse, il ouvre le compte ou le cree.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../donnees/capture.dart';
import '../../donnees/catalogue.dart';
import '../../donnees/modeles.dart' show videosDesAffiches;
import '../../donnees/session.dart';
import '../../outils/api.dart';
import '../../outils/images_reseau.dart';
import '../../outils/langue.dart';
import '../../theme/jetons.dart';
import '../../theme/theme.dart';
import '../../widgets/champ.dart';
import '../../widgets/icone.dart';
import '../../widgets/mouvement.dart';
import '../../widgets/page.dart';
import '../../widgets/photo.dart';
import '../../widgets/verre.dart';

final _formeEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

class EcranEntree extends StatefulWidget {
  const EcranEntree({super.key});

  @override
  State<EcranEntree> createState() => _EcranEntreeState();
}

class _EcranEntreeState extends State<EcranEntree> {
  final _email = TextEditingController();
  String? _erreur;
  bool _attente = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  // L adresse va au serveur, un code y part ; l ecran du code suit.
  Future<void> _continuer() async {
    final adresse = _email.text.trim();
    if (!_formeEmail.hasMatch(adresse)) {
      setState(() => _erreur = adresse.isEmpty ? t('Saisissez votre adresse e-mail.') : t('Saisissez une adresse e-mail valide.'));
      return;
    }
    setState(() => _attente = true);
    final session = Session.instance;
    try {
      await session.demanderCode(adresse);
    } on ErreurApi catch (e) {
      if (mounted) setState(() => _erreur = e.pour('email'));
      return;
    } finally {
      if (mounted) setState(() => _attente = false);
    }
    if (!mounted) return;
    context.push('/entree/code');
  }

  // Google donne un jeton d identite pour le client Web de Discover ; le serveur
  // le verifie (POST auth/google) et ouvre le compte, ou le cree.
  Future<void> _google() async {
    if (_attente) return;
    setState(() => _attente = true);
    try {
      final g = GoogleSignIn.instance;
      _googlePret ??= g.initialize(serverClientId: clientGoogle);
      await _googlePret;
      final jeton = (await g.authenticate()).authentication.idToken;
      if (jeton == null) throw const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError);
      final r = await Api.instance.post('auth/google', {'jeton': jeton, 'appareil': await modeleDuTelephone()});
      final s = Session.instance;
      await s.ouvrir(r);
      if (mounted) context.go(s.destination);
    } on GoogleSignInException catch (e) {
      // Fermer la fenetre de Google n est pas une erreur.
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        bulle(context, t('Impossible de se connecter avec Google. Réessayez ou utilisez votre adresse e-mail.'), icone: 'alerte');
      }
    } on ErreurApi catch (e) {
      if (mounted) bulle(context, e.message, icone: 'alerte');
    } on ApiInjoignable {
      if (mounted) bulle(context, t('Aucune connexion. Vérifiez le réseau, puis réessayez.'), icone: 'hors-ligne');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  /// google_sign_in ne s initialise qu une fois par lancement.
  static Future<void>? _googlePret;

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final marge = Mesures.margeDe(taille.width);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Les publications arrivent parfois apres l ecran : la mosaique les prend des qu elles sont la.
          SizedBox(
            height: taille.height * 0.5,
            child: ListenableBuilder(listenable: Listenable.merge([Catalogue.instance, ImagesReseau.pretes]), builder: (context, _) => const _Mosaique()),
          ),
          // Le formulaire se pose en bas et tient dans l ecran : rien a faire
          // defiler. Il ne defile que si le clavier lui prend la place.
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
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Monte(child: LogoUsw(taille: 56))),
                          const SizedBox(height: 14),
                          Titre(t('Bienvenue sur Discover'), style: Textes.titre, centre: true),
                          const SizedBox(height: 22),
                          Monte(
                            delai: const Duration(milliseconds: 400),
                            child: ChampVerre(
                              icone: 'enveloppe',
                              indice: t('Adresse e-mail'),
                              controleur: _email,
                              clavier: TextInputType.emailAddress,
                              action: TextInputAction.go,
                              remplissage: const [AutofillHints.email],
                              erreur: _erreur,
                              onChanged: (_) {
                                if (_erreur != null) setState(() => _erreur = null);
                              },
                              onSubmitted: (_) => _continuer(),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Monte(
                            delai: const Duration(milliseconds: 460),
                            child: BoutonVerre(texte: t('Continuer'), plein: true, onTap: _attente ? null : _continuer),
                          ),
                          const SizedBox(height: 18),
                          const Monte(delai: Duration(milliseconds: 520), child: SeparateurOu()),
                          const SizedBox(height: 18),
                          Monte(
                            delai: const Duration(milliseconds: 580),
                            child: BoutonVerre(texte: t('Continuer avec Google'), widgetIcone: const Icone('google', taille: 20), onTap: _google),
                          ),
                          const SizedBox(height: 22),
                          const Monte(delai: Duration(milliseconds: 640), child: MentionsLegales()),
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

/// Cinq colonnes de photos qui glissent lentement, une sur deux a rebours,
/// et se fondent dans le fond.
class _Mosaique extends StatefulWidget {
  const _Mosaique();

  @override
  State<_Mosaique> createState() => _MosaiqueState();
}

class _MosaiqueState extends State<_Mosaique> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (animationsReduites(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    // Trois colonnes sur un telephone, cinq sur une tablette.
    final nombre = largeur >= 600 ? 5 : 3;
    const ecart = 8.0;
    final colonne = (largeur - ecart * (nombre + 1)) / nombre;
    final hauteurPhoto = colonne * 1.33;
    final cycle = (hauteurPhoto + ecart) * 5;
    // Les photos des lieux recus, cinq par colonne, sans deux voisines du meme lieu (une
    // image du paquet tant que la sienne n est pas sur le telephone).
    final photos = Catalogue.instance.vitrine(nombre * 5, colonnes: nombre);
    final colonnes = [for (var c = 0; c < nombre; c++) photos.sublist(c * 5, c * 5 + 5)];
    // Chaque colonne est dessinee une fois (RepaintBoundary) puis seulement
    // deplacee : rien n est reconstruit ni redessine a chaque image. Le fondu
    // vers le bas est un voile du fond pose dessus, pas un masque (calque).
    return ClipRect(
      child: Stack(
        children: [
          for (var c = 0; c < nombre; c++)
            Positioned(
              left: ecart + c * (colonne + ecart),
              width: colonne,
              top: 0,
              child: AnimatedBuilder(
                animation: _c,
                // Les colonnes paires descendent, les impaires montent, chacune a son rythme.
                builder: (context, child) =>
                    Transform.translate(offset: Offset(0, -cycle + ((c.isEven ? 1 : -1) * _c.value * cycle * (1 + 0.15 * c)) % cycle - (c.isOdd ? hauteurPhoto * 0.5 : 0)), child: child),
                child: RepaintBoundary(
                  child: Column(
                    children: [
                      for (final id in [...colonnes[c], ...colonnes[c], ...colonnes[c]])
                        Padding(
                          padding: const EdgeInsets.only(bottom: ecart),
                          // Une video s y lit sans le son, en boucle, sur son affiche.
                          child: SizedBox(
                            height: hauteurPhoto,
                            child: videosDesAffiches[id] == null
                                ? PhotoArrondie(id, rayon: 16)
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      PhotoArrondie(id, rayon: 16),
                                      ClipRRect(borderRadius: BorderRadius.circular(16), child: VideoMuette(videosDesAffiches[id]!)),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Couleurs.fond.withValues(alpha: 0), Couleurs.fond.withValues(alpha: 0), Couleurs.fond],
                    stops: const [0, 0.55, 1],
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

/// L identifiant du client OAuth « Application Web » de Discover (Google Cloud) :
/// le serveur verifie que le jeton lui est destine (GOOGLE_CLIENT_IDS).
const clientGoogle = String.fromEnvironment('GOOGLE_CLIENT', defaultValue: '727021507255-nvr6ihl35mthqi4fc1sledi9tc77ihmf.apps.googleusercontent.com');
