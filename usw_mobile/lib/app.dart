import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'donnees/affichage.dart';
import 'donnees/modeles.dart';
import 'donnees/push.dart';
import 'donnees/catalogue.dart';
import 'donnees/session.dart';
import 'widgets/icone.dart';
import 'ecrans/son.dart';
import 'ecrans/accueil.dart';
import 'ecrans/carte.dart';
import 'ecrans/creer.dart';
import 'ecrans/documents.dart';
import 'ecrans/attente.dart';
import 'ecrans/etats.dart';
import 'ecrans/bienvenue.dart';
import 'ecrans/compte/changer_email.dart';
import 'ecrans/compte/completer.dart';
import 'ecrans/compte/entree.dart';
import 'ecrans/compte/code.dart';
import 'ecrans/langue.dart';
import 'ecrans/lieu.dart';
import 'ecrans/lieux_enregistres.dart';
import 'ecrans/gerer/gerer.dart';
import 'ecrans/gerer/membres.dart';
import 'ecrans/moderation.dart';
import 'ecrans/notifications.dart';
import 'ecrans/photo.dart';
import 'ecrans/profil.dart';
import 'ecrans/recherche.dart';
import 'ecrans/lifestyle.dart';
import 'ecrans/reels.dart';
import 'ecrans/reglages.dart';
import 'ecrans/ouverture.dart';
import 'outils/couverture.dart';
import 'outils/langue.dart';
import 'outils/sobriete.dart';
import 'theme/defilement.dart';
import 'theme/jetons.dart';
import 'theme/theme.dart';
import 'widgets/mouvement.dart';
import 'widgets/onglets.dart';

GoRouter creerRouteur({String depart = '/'}) => GoRouter(
  initialLocation: depart,
  // Les feuilles et les alertes ouvertes : ce qui bouge sous elles s arrete (outils/couverture.dart).
  observers: [ObservateurCouverture()],
  redirect: (context, etat) => lienPartage(etat.uri),
  routes: [
    // Une publication partagee (/p/…) : on cherche son lieu, puis sa page.
    GoRoute(
      path: '/p/:id',
      builder: (context, etat) => OuvrirPublication(id: etat.pathParameters['id'] ?? ''),
    ),
    GoRoute(path: '/', builder: (context, _) => const EcranOuverture()),
    GoRoute(path: '/bienvenue', builder: (context, _) => const EcranBienvenue()),
    GoRoute(
      path: '/entree',
      builder: (context, _) => const EcranEntree(),
      routes: [
        // Sans mot de passe : l e-mail, puis le code qu on y recoit.
        GoRoute(path: 'code', builder: (context, _) => const EcranCode()),
      ],
    ),
    GoRoute(
      path: '/completer/:etape',
      builder: (context, etat) => EcranCompleter(etape: int.tryParse(etat.pathParameters['etape'] ?? '') ?? 1),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, _, navigation) => Coquille(navigation: navigation),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/accueil', builder: (context, _) => const EcranAccueil(), routes: _communes())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/reels', builder: (context, _) => const EcranReels(), routes: _communes())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/carte', builder: (context, _) => const EcranCarte(), routes: _communes())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profil',
              builder: (context, _) => const EcranProfil(),
              routes: [
                ..._communes(),
                GoRoute(
                  path: 'reglages',
                  builder: (context, _) => const EcranReglages(),
                  // La langue de Discover : celle du telephone, ou une autre.
                  routes: [GoRoute(path: 'langue', builder: (context, _) => const EcranLangue())],
                ),
                GoRoute(path: 'modifier', builder: (context, _) => const EcranModifierProfil()),
                GoRoute(
                  path: 'acces',
                  builder: (context, _) => const EcranAcces(),
                  routes: [GoRoute(path: 'adresse', builder: (context, _) => const EcranChangerEmail())],
                ),
                GoRoute(path: 'bloques', builder: (context, _) => const EcranBloques()),
                GoRoute(path: 'lieux', builder: (context, _) => const EcranLieuxEnregistres()),
                GoRoute(path: 'lifestyle', builder: (context, _) => const EcranMonLifestyle()),
                GoRoute(
                  path: 'collection/:n',
                  builder: (context, etat) => EcranCollection(index: int.tryParse(etat.pathParameters['n'] ?? '') ?? 0),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // Creer : le « + » ouvre la feuille (ouvrirCreer), puis ces pages.
    GoRoute(
      path: '/creer/autoriser',
      builder: (context, etat) => EcranAutoriser(quoi: etat.uri.queryParameters['quoi'] ?? 'photo'),
    ),
    // Un ecran noir, sans transition : l appareil photo s ouvre par-dessus.
    GoRoute(
      path: '/creer/prise',
      pageBuilder: (context, etat) => NoTransitionPage(
        child: EcranPrise(quoi: etat.uri.queryParameters['quoi'] ?? 'photo', fichier: etat.uri.queryParameters['fichier']),
      ),
    ),
    GoRoute(path: '/creer/montage', builder: (context, _) => const EcranMontage()),
    GoRoute(
      path: '/creer/completer',
      builder: (context, etat) => EcranCompleterInfos(lot: etat.uri.queryParameters['lot'] == '1'),
    ),
    GoRoute(path: '/creer/lot', builder: (context, _) => const EcranLot()),
    GoRoute(
      path: '/creer/details',
      builder: (context, etat) => EcranDetails(reel: etat.uri.queryParameters['reel'] == '1', declaree: etat.uri.queryParameters['declare'] == '1'),
    ),
    GoRoute(path: '/creer/lieu', builder: (context, _) => const EcranChoisirLieu()),
    // Mes envois et mes telechargements : une photo touchee s ouvre ici (outils/chemins.dart).
    GoRoute(path: '/creer/envois', builder: (context, _) => const EcranEnvois(), routes: _communes()),
    GoRoute(
      path: '/notifications',
      builder: (context, _) => const EcranNotifications(),
      routes: [
        GoRoute(path: 'reglages', builder: (context, _) => const EcranReglagesNotifications()),
        GoRoute(path: 'motif', builder: (context, _) => const EcranMotif()),
        // Une photo, un lieu, un createur ouverts depuis une notification restent ici, par-dessus
        // la liste : poussee vers un onglet, la page doublait la barre d onglets (meme cle, page noire).
        ..._communes(),
      ],
    ),
    // Aide, regles, conditions, confidentialite.
    GoRoute(
      path: '/document/:id',
      builder: (context, etat) => EcranDocument(id: etat.pathParameters['id'] ?? ''),
    ),
    // Hors ligne, introuvable, publication refusee (?titre=&motif=&contenu=).
    GoRoute(
      path: '/etat/:id',
      builder: (context, etat) =>
          EcranEtat(etat: etat.pathParameters['id'] ?? '', titre: etat.uri.queryParameters['titre'], motif: etat.uri.queryParameters['motif'], contenu: etat.uri.queryParameters['contenu']),
    ),
    // « Gérer Discover » : l equipe seule (le serveur repond 404 a tout autre compte).
    GoRoute(
      path: '/gerer',
      builder: (context, _) => const EcranGerer(),
      routes: [
        GoRoute(
          path: 'membre/:pseudo',
          builder: (context, etat) => EcranFicheMembre(pseudo: etat.pathParameters['pseudo'] ?? ''),
        ),
        ..._communes(),
      ],
    ),
    GoRoute(
      path: '/moderation',
      builder: (context, etat) => EcranModeration(file: int.tryParse(etat.uri.queryParameters['file'] ?? '') ?? 0),
      routes: [
        GoRoute(
          path: 'decision',
          builder: (context, etat) => EcranDecision(index: int.tryParse(etat.uri.queryParameters['n'] ?? '') ?? 0),
        ),
      ],
    ),
  ],
);

class AppUsw extends StatefulWidget {
  const AppUsw({super.key, this.depart = '/'});

  /// L ecran de depart : l ouverture, ou un autre pour les tests.
  final String depart;

  @override
  State<AppUsw> createState() => _AppUswState();
}

class _AppUswState extends State<AppUsw> with WidgetsBindingObserver {
  late final _routeur = creerRouteur(depart: widget.depart);
  final _affichage = Affichage.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _affichage.addListener(_changer);
    Langue.instance.addListener(_changer);
    Sobriete.instance.addListener(_sobriete);
    Couleurs.sombre = _nuit();
    // go, pas push : par-dessus un ecran hors onglets (notifications, creation), pousser une page
    // d onglet doublait la barre d onglets (meme cle) et laissait une page noire.
    Push.instance.ouvrir = (chemin) => _routeur.push(chemin);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _affichage.removeListener(_changer);
    Langue.instance.removeListener(_changer);
    Sobriete.instance.removeListener(_sobriete);
    _routeur.dispose();
    super.dispose();
  }

  bool _nuit() => switch (_affichage.mode) {
    ModeTheme.clair => false,
    ModeTheme.sombre => true,
    ModeTheme.systeme => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
  };

  // Le telephone passe en sombre (ou revient en clair) : on suit, s il le faut.
  @override
  void didChangePlatformBrightness() {
    // Android le redit parfois sans que rien ne change (retour dans l appli).
    if (_nuit() != Couleurs.sombre) _changer();
  }

  // La langue du telephone change : Discover suit, si on n en a pas choisi une.
  @override
  void didChangeLocales(List<Locale>? locales) => Langue.instance.suivreLeTelephone();

  // De retour dans Discover : on a pu bouger, les distances se recalculent depuis ici.
  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) Catalogue.instance.repositionner();
  }

  // Le telephone chauffe, ou refroidit : les animations suivent (MediaQuery).
  void _sobriete() => setState(() {});

  // Les couleurs se lisent a la construction : quand le theme ou la police
  // change, tout l arbre se reconstruit, sans perdre la page ouverte.
  void _changer() {
    Couleurs.sombre = _nuit();
    setState(() {});
    void marquer(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marquer);
    }

    (context as Element).visitChildren(marquer);
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: barreDuTheme,
    child: MaterialApp.router(
      title: 'Discover',
      debugShowCheckedModeBanner: false,
      theme: themeUsw(),
      routerConfig: _routeur,
      scrollBehavior: const DefilementUsw(),
      // La langue choisie (outils/langue.dart) ; le calendrier et les champs de Flutter suivent.
      locale: Langue.instance.localeMaterial,
      supportedLocales: [for (final l in kMaterialSupportedLanguages) Locale(l)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Les animations : toutes par defaut, reduites si on le choisit. Tant que
      // le telephone chauffe ou economise sa batterie, seuls les mouvements
      // continus s arretent (sobriete.dart, mouvementsContinus).
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: _affichage.reduireAnimations),
        child: Allegement(leger: Sobriete.instance.leger, child: enfant!),
      ),
    ),
  );
}

/// Un lien partage (discover.simeonamoussou.com/l/…, /@…) ouvert dans l application : la page
/// qu il montre, dans l onglet Accueil. Nul pour tout autre chemin.
String? lienPartage(Uri lien) {
  final s = lien.pathSegments;
  if (s.length == 2 && s[0] == 'l' && s[1].isNotEmpty) return '/accueil/lieu/${s[1]}';
  if (s.length == 1 && s[0].length > 1 && s[0].startsWith('@')) return '/accueil/createur/${s[0].substring(1)}';
  return null;
}

bool _cEstMoi(String? pseudo) {
  final s = Session.instance;
  final p = (pseudo ?? '').replaceFirst('@', '').toLowerCase();
  return s.connecte && p.isNotEmpty && p == s.nomUtilisateur.toLowerCase();
}

/// Une publication partagee : son lieu se lit sur le serveur, puis sa page s ouvre a sa place.
class OuvrirPublication extends StatefulWidget {
  const OuvrirPublication({super.key, required this.id});

  final String id;

  @override
  State<OuvrirPublication> createState() => _OuvrirPublicationState();
}

class _OuvrirPublicationState extends State<OuvrirPublication> {
  bool _introuvable = false;

  @override
  void initState() {
    super.initState();
    Catalogue.instance.chargerPublication(widget.id).then((p) {
      if (!mounted) return;
      final lieu = p?.lieu;
      if (lieu == null) return setState(() => _introuvable = true);
      context.go('/accueil/lieu/$lieu/photo/${widget.id}');
    });
  }

  @override
  Widget build(BuildContext context) => _introuvable ? const EcranEtat(etat: 'introuvable') : Scaffold(body: const Center(child: LogoQuiTourne(taille: 34)));
}

/// Les pages communes a chaque onglet (outils/chemins.dart) : elles s ouvrent
/// dans l onglet ou l on est, la barre d onglets reste sur lui.
List<RouteBase> _communes() => [
  // La recherche et ses filtres gardent la barre d onglets.
  GoRoute(path: 'recherche', builder: (context, _) => const EcranRecherche()),
  // Les lifestyles visibles (la recherche), et celui d un membre.
  GoRoute(path: 'lifestyles', builder: (context, _) => const EcranLifestyles()),
  GoRoute(
    path: 'lifestyle/:pseudo',
    builder: (context, etat) => EcranLifestyleDe(pseudo: etat.pathParameters['pseudo'] ?? ''),
  ),
  // La page d un son (le disque d un reel) : ses reels, « Utiliser ce son ».
  GoRoute(
    path: 'son/:id',
    builder: (context, etat) => EcranSon(id: etat.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: 'createur/:pseudo',
    // Mon propre nom (mon lien partage, une mention de moi) : mon profil, pas la page d un createur.
    redirect: (context, etat) => _cEstMoi(etat.pathParameters['pseudo']) ? '/profil' : null,
    builder: (context, etat) => EcranCreateur(pseudo: etat.pathParameters['pseudo'] ?? ''),
  ),
  // La page d un lieu garde la barre d onglets (Accueil actif).
  GoRoute(
    path: 'lieu/:id',
    builder: (context, etat) => LieuAttendu(
      id: etat.pathParameters['id'] ?? '',
      construire: (lieu) => EcranLieu(lieu: lieu),
    ),
    routes: [
      // :n est le rang de la photo dans le lieu, ou l identifiant de la publication (un lien stable).
      // Un reel filme dans Discover s ouvre dans le lecteur des Reels, pas sur la page d une photo.
      GoRoute(
        path: 'photo/:n',
        builder: (context, etat) {
          final n = etat.pathParameters['n'] ?? '';
          final connue = Catalogue.instance.publication(n);
          // Une publication de lifestyle : seule sur sa page (pas avec les photos de son lieu).
          if (connue != null && connue.duLifestyle) return EcranPhoto(lieu: Catalogue.instance.lieuSeul(connue), index: 0);
          if (connue?.filmeeDansDiscover == true) return EcranUnReel(id: n);
          return LieuAttendu(
            id: etat.pathParameters['id'] ?? '',
            publication: n,
            construire: (lieu) {
              final publications = publicationsDe(lieu);
              if (publications.isEmpty) return const EcranEtat(etat: 'introuvable');
              final rang = rangDans(lieu, n).clamp(0, publications.length - 1);
              final p = publications[rang];
              if (p.filmeeDansDiscover && p.id != null) return EcranUnReel(id: p.id!);
              return EcranPhoto(lieu: lieu, index: rang, commentaires: etat.uri.queryParameters['commentaires'] == '1');
            },
          );
        },
      ),
    ],
  ),
];
