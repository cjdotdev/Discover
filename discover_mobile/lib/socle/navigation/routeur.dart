import 'package:go_router/go_router.dart';

import '../../fonctionnalites/compte/ecrans/bienvenue.dart';
import '../../fonctionnalites/compte/ecrans/code.dart';
import '../../fonctionnalites/compte/ecrans/completer_profil.dart';
import '../../fonctionnalites/compte/ecrans/creer_mot_de_passe.dart';
import '../../fonctionnalites/compte/ecrans/entree.dart';
import '../../fonctionnalites/compte/ecrans/mot_de_passe.dart';
import '../../fonctionnalites/compte/ecrans/nouveau_mot_de_passe.dart';
import '../../fonctionnalites/compte/ecrans/oubli.dart';
import '../../fonctionnalites/compte/ecrans/ouverture.dart';
import '../../fonctionnalites/contenus/ecrans/carte.dart';
import '../../fonctionnalites/contenus/ecrans/commentaires.dart';
import '../../fonctionnalites/contenus/ecrans/photo.dart';
import '../../fonctionnalites/contenus/ecrans/reels.dart';
import '../../fonctionnalites/decouverte/ecrans/accueil.dart';
import '../../fonctionnalites/decouverte/ecrans/createur.dart';
import '../../fonctionnalites/decouverte/ecrans/filtres.dart';
import '../../fonctionnalites/decouverte/ecrans/lieu.dart';
import '../../fonctionnalites/decouverte/ecrans/notifications.dart';
import '../../fonctionnalites/decouverte/ecrans/recherche.dart';
import '../../fonctionnalites/profil/ecrans/modifier_profil.dart';
import '../../fonctionnalites/profil/ecrans/profil.dart';
import '../../fonctionnalites/profil/ecrans/reglages.dart';
import '../../fonctionnalites/publication/ecrans/autorisations.dart';
import '../../fonctionnalites/publication/ecrans/completer_capture.dart';
import '../../fonctionnalites/publication/ecrans/creer.dart';
import '../../fonctionnalites/publication/ecrans/details.dart';
import '../../fonctionnalites/publication/ecrans/en_route.dart';
import '../../fonctionnalites/publication/ecrans/indiquer_lieu.dart';
import 'coquille_onglets.dart';
import 'routes.dart';

GoRoute _page(String chemin, GoRouterWidgetBuilder ecran) => GoRoute(path: chemin, builder: ecran);

/// La carte de l'application : chaque adresse mène à son écran.
GoRouter creerRouteur() {
  return GoRouter(
    initialLocation: Routes.ouverture,
    routes: [
      // Le compte, hors de la barre d'onglets.
      _page(Routes.ouverture, (_, _) => const EcranOuverture()),
      _page(Routes.bienvenue, (_, _) => const EcranBienvenue()),
      _page(Routes.entree, (_, _) => const EcranEntree()),
      _page(Routes.motDePasse, (_, etat) => EcranMotDePasse(email: _email(etat))),
      _page(Routes.creerMotDePasse, (_, etat) => EcranCreerMotDePasse(email: _email(etat))),
      _page(
        Routes.code,
        (_, etat) => EcranCode(email: _email(etat), oubli: etat.uri.queryParameters['but'] == 'oubli'),
      ),
      _page(Routes.oubli, (_, etat) => EcranOubli(email: _email(etat))),
      _page(
        Routes.nouveauMotDePasse,
        (_, etat) => EcranNouveauMotDePasse(email: _email(etat), code: etat.uri.queryParameters['code'] ?? ''),
      ),
      _page(Routes.completerProfil, (_, _) => const EcranCompleterProfil()),

      // Les cinq onglets.
      StatefulShellRoute.indexedStack(
        builder: (_, _, coquille) => CoquilleOnglets(coquille: coquille),
        branches: [
          StatefulShellBranch(routes: [_page(Routes.accueil, (_, _) => const EcranAccueil())]),
          StatefulShellBranch(routes: [_page(Routes.reels, (_, _) => const EcranReels())]),
          StatefulShellBranch(routes: [_page(Routes.creer, (_, _) => const EcranCreer())]),
          StatefulShellBranch(routes: [_page(Routes.carte, (_, _) => const EcranCarte())]),
          StatefulShellBranch(routes: [_page(Routes.profil, (_, _) => const EcranProfil())]),
        ],
      ),

      // Les écrans qui passent par-dessus les onglets.
      _page(Routes.filtres, (_, _) => const EcranFiltres()),
      _page(Routes.recherche, (_, _) => const EcranRecherche()),
      _page(Routes.notifications, (_, _) => const EcranNotifications()),
      _page('/lieu/:id', (_, etat) => EcranLieu(id: etat.pathParameters['id']!)),
      _page('/createur/:nom', (_, etat) => EcranCreateur(nom: etat.pathParameters['nom']!)),
      _page('/photo/:id', (_, etat) => EcranPhoto(id: etat.pathParameters['id']!)),
      _page('/commentaires/:id', (_, etat) => EcranCommentaires(id: etat.pathParameters['id']!)),
      _page(Routes.autorisations, (_, _) => const EcranAutorisations()),
      _page(Routes.details, (_, _) => const EcranDetails()),
      _page(Routes.completerCapture, (_, _) => const EcranCompleterCapture()),
      _page(Routes.indiquerLieu, (_, _) => const EcranIndiquerLieu()),
      _page(Routes.enRoute, (_, _) => const EcranEnRoute()),
      _page(Routes.modifierProfil, (_, _) => const EcranModifierProfil()),
      _page(Routes.reglages, (_, _) => const EcranReglages()),
    ],
  );
}

final routeur = creerRouteur();

String _email(GoRouterState etat) => etat.uri.queryParameters['email'] ?? '';
