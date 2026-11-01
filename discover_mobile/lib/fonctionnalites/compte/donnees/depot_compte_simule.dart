import '../../../socle/api/erreur_api.dart';
import '../../../socle/session/session.dart';
import 'depot_compte.dart';
import 'profil.dart';

/// Le compte sans serveur, pour présenter l'application et travailler sans attendre le backend.
/// Compte déjà inscrit : membre@discover.bj / Discover1. Code de vérification : 123456.
class DepotCompteSimule implements DepotCompte {
  static const _emailConnu = 'membre@discover.bj';
  static const _motDePasseConnu = 'Discover1';
  static const _codeValable = '123456';

  Future<void> _attendre() => Future.delayed(const Duration(milliseconds: 300));

  @override
  Future<bool> emailExiste(String email) async {
    await _attendre();
    return email == _emailConnu;
  }

  @override
  Future<void> connexion(String email, String motDePasse) async {
    await _attendre();
    if (motDePasse != _motDePasseConnu) {
      throw const ErreurApi(422, 'Mot de passe incorrect.', {
        'mot_de_passe': ['Mot de passe incorrect. Réessayez ou choisissez « Mot de passe oublié ».'],
      });
    }
    await Session.instance.ouvrir(jeton: 'jeton-simule', profilComplet: true);
  }

  @override
  Future<void> inscription(String email, String motDePasse) => _attendre();

  @override
  Future<void> verifierCode(String email, String code) async {
    await _attendre();
    _controlerCode(code);
    await Session.instance.ouvrir(jeton: 'jeton-simule', profilComplet: false);
  }

  @override
  Future<void> renvoyerCode(String email) => _attendre();

  @override
  Future<void> demanderOubli(String email) => _attendre();

  @override
  Future<void> nouveauMotDePasse(String email, String code, String motDePasse) async {
    await _attendre();
    _controlerCode(code);
  }

  @override
  Future<void> connexionGoogle() async {
    await _attendre();
    await Session.instance.ouvrir(jeton: 'jeton-simule', profilComplet: false);
  }

  @override
  Future<void> enregistrerProfil(Profil profil) async {
    await _attendre();
    await Session.instance.marquerProfilComplet();
  }

  void _controlerCode(String code) {
    if (code != _codeValable) {
      throw const ErreurApi(422, 'Ce code est incorrect.', {
        'code': ['Ce code est incorrect ou a expiré.'],
      });
    }
  }
}
