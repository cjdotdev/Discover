// Une feuille, une alerte ou un menu ouvert par-dessus la page : ce qui bouge dessous (les
// videos des grilles, les piles) s arrete le temps qu il est la, puis reprend. Le verre de la
// feuille relit le fond a chaque image ou il change ; un fond immobile ne lui coute plus rien :
// l appui long et l ouverture restent fluides, le verre au maximum.
import 'package:flutter/widgets.dart';

/// Le nombre de feuilles, alertes et menus ouverts sur la page.
final pageCouverte = ValueNotifier<int>(0);

/// A poser sur le navigateur principal (ou s ouvrent les feuilles et les alertes).
class ObservateurCouverture extends NavigatorObserver {
  final _ouvertes = <Route<dynamic>>{};

  void _compter() => pageCouverte.value = _ouvertes.length;

  void _ajouter(Route<dynamic>? route) {
    if (route is PopupRoute && _ouvertes.add(route)) _compter();
  }

  // Des la fermeture : la page reprend pendant que la feuille descend.
  void _retirer(Route<dynamic>? route) {
    if (_ouvertes.remove(route)) _compter();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _ajouter(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _retirer(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _retirer(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _retirer(oldRoute);
    _ajouter(newRoute);
  }
}
