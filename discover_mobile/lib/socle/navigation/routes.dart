// Toutes les adresses de l'application, à un seul endroit.
abstract final class Routes {
  // Compte (Siméon)
  static const ouverture = '/';
  static const bienvenue = '/bienvenue';
  static const entree = '/entree';
  static const motDePasse = '/entree/mot-de-passe';
  static const creerMotDePasse = '/entree/creer-mot-de-passe';
  static const code = '/entree/code';
  static const oubli = '/entree/oubli';
  static const nouveauMotDePasse = '/entree/nouveau-mot-de-passe';
  static const completerProfil = '/completer-profil';

  // Découverte (Joël)
  static const accueil = '/accueil';
  static const filtres = '/filtres';
  static const recherche = '/recherche';
  static const notifications = '/notifications';
  static String lieu(String id) => '/lieu/$id';
  static String createur(String nom) => '/createur/$nom';

  // Contenus (Djamal)
  static const reels = '/reels';
  static const carte = '/carte';
  static String photo(String id) => '/photo/$id';
  static String commentaires(String id) => '/commentaires/$id';

  // Publication et profil (Ainé Mao)
  static const creer = '/creer';
  static const autorisations = '/creer/autorisations';
  static const details = '/creer/details';
  static const completerCapture = '/creer/completer';
  static const indiquerLieu = '/creer/lieu';
  static const enRoute = '/creer/en-route';
  static const profil = '/profil';
  static const modifierProfil = '/profil/modifier';
  static const reglages = '/profil/reglages';

  /// Ajoute l'e-mail (et le reste) à une adresse : il suit le membre d'un écran à l'autre.
  static String avec(String chemin, Map<String, String> parametres) =>
      Uri(path: chemin, queryParameters: parametres).toString();
}
