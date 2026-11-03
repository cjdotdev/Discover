// Les pages communes (la recherche, un lieu, une photo, un createur) s ouvrent
// dans l onglet ou l on est : depuis les reels, la recherche reste dans les
// reels, avec la barre d onglets sur Reels, au lieu de sauter sur l accueil.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Les pages qui ont les pages communes sous elles (app.dart) : les quatre onglets, et,
/// hors onglets, les notifications, Gerer et Mes envois. Une page commune poussee depuis
/// une page hors onglets vers un onglet doublait la barre d onglets (meme cle, page noire).
const hotesDesPagesCommunes = ['/accueil', '/reels', '/carte', '/profil', '/notifications', '/gerer', '/creer/envois'];

/// Le chemin de `suite` (par exemple « lieu/grand-popo ») sous la page ou l on est.
String ici(BuildContext context, String suite) {
  String chemin = '';
  // La page ou l on est (GoRouterState) : l adresse du routeur, elle, reste celle de l onglet
  // quand une page hors onglets (notifications) est poussee par-dessus. Une feuille, hors des
  // pages, n a pas d etat : c est alors la page du dessus (la derniere poussee) qui compte.
  try {
    chemin = GoRouterState.of(context).uri.path;
  } catch (_) {
    try {
      chemin = Uri.parse(GoRouter.of(context).routerDelegate.currentConfiguration.lastOrNull?.matchedLocation ?? '').path;
    } catch (_) {}
  }
  // Le plus long qui convient : /creer/envois/lieu/… est sous Mes envois.
  String? hote;
  for (final h in hotesDesPagesCommunes) {
    if ((chemin == h || chemin.startsWith('$h/')) && h.length > (hote?.length ?? 0)) hote = h;
  }
  return '${hote ?? '/accueil'}/$suite';
}
