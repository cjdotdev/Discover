import '../../../socle/api/client_api.dart';
import 'depot_compte_api.dart';
import 'depot_compte_simule.dart';
import 'profil.dart';

/// Tout ce que les écrans du compte demandent au serveur. Les écrans ne connaissent que cette
/// liste : on passe des données simulées à la vraie API sans toucher à un seul écran.
abstract class DepotCompte {
  /// POST auth/email : répond seulement oui ou non, jamais le nom ni la photo.
  Future<bool> emailExiste(String email);

  /// POST auth/connexion
  Future<void> connexion(String email, String motDePasse);

  /// POST auth/inscription : le compte attend son code, reçu par e-mail.
  Future<void> inscription(String email, String motDePasse);

  /// POST auth/code : ouvre la session.
  Future<void> verifierCode(String email, String code);

  /// POST auth/code/renvoyer
  Future<void> renvoyerCode(String email);

  /// POST auth/oubli : envoie un code, que l'adresse existe ou non.
  Future<void> demanderOubli(String email);

  /// POST auth/nouveau-mot-de-passe
  Future<void> nouveauMotDePasse(String email, String code, String motDePasse);

  /// POST auth/google
  Future<void> connexionGoogle();

  /// PATCH moi et POST moi/avatar
  Future<void> enregistrerProfil(Profil profil);
}

/// Sans adresse d'API au lancement, l'application tourne avec les données simulées.
final DepotCompte depotCompte = ClientApi.configuree ? DepotCompteApi() : DepotCompteSimule();
