import '../../../socle/api/client_api.dart';
import '../../../socle/api/erreur_api.dart';
import '../../../socle/session/session.dart';
import 'depot_compte.dart';
import 'profil.dart';

/// Le compte, avec la vraie API Laravel (voir repartition.md, section Backend).
class DepotCompteApi implements DepotCompte {
  DepotCompteApi({ClientApi? api}) : _api = api ?? ClientApi();

  final ClientApi _api;

  // Toutes les connexions répondent de la même façon : un jeton et l'état du profil.
  Future<void> _ouvrir(Map<String, dynamic> reponse) {
    return Session.instance.ouvrir(
      jeton: reponse['jeton'] as String,
      profilComplet: reponse['profil_complet'] as bool? ?? false,
    );
  }

  @override
  Future<bool> emailExiste(String email) async {
    final reponse = await _api.post('auth/email', {'email': email});
    return reponse['existe'] as bool;
  }

  @override
  Future<void> connexion(String email, String motDePasse) async {
    await _ouvrir(await _api.post('auth/connexion', {'email': email, 'mot_de_passe': motDePasse}));
  }

  @override
  Future<void> inscription(String email, String motDePasse) async {
    await _api.post('auth/inscription', {'email': email, 'mot_de_passe': motDePasse});
  }

  @override
  Future<void> verifierCode(String email, String code) async {
    await _ouvrir(await _api.post('auth/code', {'email': email, 'code': code}));
  }

  @override
  Future<void> renvoyerCode(String email) async {
    await _api.post('auth/code/renvoyer', {'email': email});
  }

  @override
  Future<void> demanderOubli(String email) async {
    await _api.post('auth/oubli', {'email': email});
  }

  @override
  Future<void> nouveauMotDePasse(String email, String code, String motDePasse) async {
    await _api.post('auth/nouveau-mot-de-passe', {'email': email, 'code': code, 'mot_de_passe': motDePasse});
  }

  // La connexion Google attend les identifiants du projet (tâche T03 de repartition.md).
  @override
  Future<void> connexionGoogle() async {
    throw const ErreurApi(501, "La connexion avec Google n'est pas encore branchée.");
  }

  @override
  Future<void> enregistrerProfil(Profil profil) async {
    await _api.patch('moi', {
      'nom_affiche': profil.nomAffiche,
      'nom_utilisateur': profil.nomUtilisateur,
      'bio': profil.bio,
      'pays': profil.pays,
      'ville': profil.ville,
      'utiliser_position': profil.utiliserPosition,
      'types_aimes': profil.gouts.toList(),
    });
    final photo = profil.photo;
    if (photo != null) await _api.postFichier('moi/avatar', 'avatar', photo, 'avatar.jpg');
    await Session.instance.marquerProfilComplet();
  }
}
