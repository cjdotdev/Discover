import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogue.dart';
import 'communaute.dart';
import 'envois.dart';
import 'lifestyle.dart';
import 'mes_publications.dart';
import 'push.dart';
import 'telechargements.dart';
import '../outils/api.dart';
import '../outils/langue.dart';
import '../outils/verrou.dart';

/// La session du membre (lot 1). Le jeton Sanctum et le membre sont gardes
/// sur le telephone : on rouvre USW deja connecte, meme sans reseau, et le
/// profil se met a jour aupres du serveur des qu il repond (GET moi).
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  static const _cleMembre = 'membre';
  static const _cleBienvenue = 'bienvenue_vue';
  static const _cleProfilAEnvoyer = 'profil_a_envoyer';
  static const _clePhotoAEnvoyer = 'photo_a_envoyer';

  /// Le chemin de la photo de profil gardee sur ce telephone (outils/photo_profil.dart).
  static const clePhotoProfil = 'photo_profil';

  /// Les envois du profil et de la photo, l un apres l autre : sinon la reponse du profil,
  /// partie avant la photo mais arrivee apres, effacait l adresse de la photo neuve.
  Future<void> _file = Future<void>.value();

  Future<T> _aLaSuite<T>(Future<T> Function() envoi) {
    final suite = _file.then((_) => envoi());
    _file = suite.then<void>((_) {}, onError: (_) {});
    return suite;
  }

  String email = '';

  /// Le défi du dernier code demandé : le serveur ne laisse essayer ce code qu'à ce téléphone.
  String? _defi;
  String nomAffiche = '';
  String nomUtilisateur = '';
  String bio = '';
  String site = '';
  String pays = 'Bénin';
  String ville = 'Cotonou';
  bool position = true;
  final Set<String> interets = {};
  bool connecte = false;
  bool profilComplete = false;

  /// Un compte lie a Google : il entre avec Google, et son adresse est celle de Google.
  bool google = false;

  /// La bienvenue (E01) ne se montre qu au premier lancement.
  bool bienvenueVue = false;

  /// La photo de profil : un fichier garde dans l application (photo_profil.dart).
  String? photo;

  /// La photo de profil sur le serveur (son adresse), si elle n est pas sur ce telephone.
  String? avatar;

  /// Mes compteurs, d apres le serveur (nuls avant sa reponse).
  int? abonnes;
  int? abonnements;
  int? nombreContenus;

  void changerPhoto(String? chemin) {
    photo = chemin;
    notifyListeners();
  }

  // ------------------------------------------------------------ au demarrage

  /// Le jeton et le membre gardes : USW s ouvre connecte, puis se rafraichit.
  Future<void> charger() async {
    try {
      bienvenueVue = (await SharedPreferences.getInstance()).getBool(_cleBienvenue) ?? false;
    } catch (_) {}
    await Api.instance.charger();
    if (Api.instance.jeton == null) return;
    try {
      final brut = (await SharedPreferences.getInstance()).getString(_cleMembre);
      if (brut != null) _appliquer((jsonDecode(brut) as Map).cast<String, dynamic>(), garder: false);
      // Complete hors ligne : on ne le redemande pas, il partira au serveur.
      if ((await SharedPreferences.getInstance()).getBool(_cleProfilAEnvoyer) ?? false) profilComplete = true;
    } catch (_) {}
    connecte = true;
    unawaited(rafraichir());
  }

  /// Le membre tel que le serveur le connait (le jeton a pu expirer : on sort).
  Future<void> rafraichir() async {
    try {
      await _envoyerProfilEnAttente();
      final r = await Api.instance.get('moi');
      _appliquer((r.json['data'] as Map).cast<String, dynamic>());
      notifyListeners();
      // Une photo choisie qui n est pas arrivee au serveur (pas de reseau, une coupure, ou une
      // ancienne version qui ne la renvoyait pas) repart.
      if (photo != null && (avatar == null || ((await SharedPreferences.getInstance()).getBool(_clePhotoAEnvoyer) ?? false))) {
        await envoyerPhoto().catchError((_) {});
      }
    } on ErreurApi catch (e) {
      if (e.code == 401) _vider();
    } on ApiInjoignable {
      // Hors ligne : on garde ce qu on sait.
    }
  }

  // ------------------------------------------------------------ entrer

  /// Sans mot de passe : un code a 6 chiffres part a cette adresse, qu un
  /// compte existe ou non (le code l ouvre, ou le cree). Une erreur du
  /// serveur (trop de codes demandes, e-mail qui ne part pas) remonte telle
  /// quelle (ErreurApi) ; sans reseau aussi, avec sa phrase.
  Future<void> demanderCode(String adresse) async {
    final nouvelle = adresse.trim().toLowerCase();
    // Une autre adresse : un autre défi. La même : on garde le sien (le nouveau code remplace l'ancien).
    if (nouvelle != email) _defi = null;
    email = nouvelle;
    try {
      final r = await Api.instance.post('auth/code/envoyer', {'email': email, 'defi': ?_defi});
      _defi = r.json['defi'] as String? ?? _defi;
    } on ApiInjoignable {
      throw ErreurApi(0, t('Aucune connexion. Vérifiez le réseau, puis réessayez.'));
    } finally {
      _nomsDepuisEmail();
      notifyListeners();
    }
  }

  /// Modifier l adresse, etape 1 : un code part a la nouvelle adresse (le verrou du telephone
  /// a ete demande avant). Les refus du serveur remontent tels quels (ErreurApi).
  Future<void> demanderChangementEmail(String adresse) async {
    try {
      await Api.instance.post('moi/email', {'email': adresse});
    } on ApiInjoignable {
      throw ErreurApi(0, t('Aucune connexion. Vérifiez le réseau, puis réessayez.'));
    }
  }

  /// Modifier l adresse, etape 2 : le bon code, et l adresse du compte change.
  Future<void> confirmerChangementEmail(String code) async {
    try {
      final r = await Api.instance.post('moi/email/confirmer', {'code': code});
      _appliquer((r.json['data'] as Map).cast<String, dynamic>());
      notifyListeners();
    } on ApiInjoignable {
      throw ErreurApi(0, t('Aucune connexion. Vérifiez le réseau, puis réessayez.'));
    }
  }

  /// Le code reçu par e-mail : il ouvre le compte (ou le crée).
  Future<Reponse> verifierCode(String code, {String? appareil}) => Api.instance.post('auth/code', {'email': email, 'code': code, 'defi': _defi ?? '', 'appareil': appareil});

  /// La bienvenue est passee : les prochains lancements vont droit a l entree ou a l accueil.
  void marquerBienvenueVue() {
    bienvenueVue = true;
    SharedPreferences.getInstance().then((p) => p.setBool(_cleBienvenue, true)).ignore();
  }

  /// Apres l ouverture : l accueil (connecte), la fin du profil, ou l entree.
  String get destination => !connecte ? '/entree' : (profilComplete ? '/accueil' : '/completer/1');

  /// Une reponse « jeton + utilisateur » : le membre est connecte sur ce telephone.
  Future<void> ouvrir(Reponse r) async {
    await Api.instance.garderJeton(r.json['jeton'] as String?);
    _appliquer((r.json['utilisateur'] as Map).cast<String, dynamic>());
    connecte = true;
    notifyListeners();
    // Ce qui depend du compte : qui je suis, mes collections, ma part de chaque publication.
    unawaited(Communaute.instance.charger());
    unawaited(Catalogue.instance.rafraichir());
    unawaited(MesPublications.instance.accorderAuServeur());
    unawaited(Push.instance.enregistrer());
    unawaited(Envois.instance.apresConnexion());
  }

  /// Le profil complete (E36) ou modifie (E21) part au serveur, avec la photo.
  Future<void> envoyerProfil({bool complet = false}) => _aLaSuite(() async {
    if (Api.instance.jeton == null) return;
    final r = await Api.instance.patch('moi', {
      'nom_affiche': nomAffiche,
      'nom_utilisateur': nomUtilisateur,
      'bio': bio.isEmpty ? null : bio,
      'site': site.isEmpty ? null : site,
      'pays': pays,
      'ville': ville,
      'position': position,
      'types_aimes': interets.toList(),
      if (complet) 'profil_complete': true,
    });
    _appliquer((r.json['data'] as Map).cast<String, dynamic>());
    notifyListeners();
  });

  /// Le profil complete sans reseau : il est garde comme complet ici, et part
  /// au serveur des qu il repond (rafraichir). On ne le redemande pas.
  Future<void> profilEnAttente() async {
    profilComplete = true;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_cleProfilAEnvoyer, true);
    } catch (_) {}
  }

  /// Le profil est arrive sur le serveur : il ne repart plus a la prochaine ouverture.
  Future<void> profilEnvoye() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_cleProfilAEnvoyer);
    } catch (_) {}
  }

  Future<void> _envoyerProfilEnAttente() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_cleProfilAEnvoyer) ?? false)) return;
    try {
      await envoyerProfil(complet: true);
    } on ErreurApi catch (e) {
      if (e.code == 401) rethrow;
      // Refuse (un nom deja pris) : le serveur dira de le completer a nouveau.
      await p.remove(_cleProfilAEnvoyer);
      return;
    }
    await p.remove(_cleProfilAEnvoyer);
    await envoyerPhoto();
  }

  /// La photo de profil part au serveur (WebP 512 px la-bas). Tant qu elle n y est pas,
  /// elle reste a envoyer : elle repart a la prochaine ouverture (rafraichir).
  Future<void> envoyerPhoto() => _aLaSuite(() async {
    final chemin = photo;
    if (Api.instance.jeton == null || chemin == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_clePhotoAEnvoyer, true);
    final r = await Api.instance.envoyerFichier('moi/avatar', 'avatar', File(chemin));
    _appliquer((r.json['data'] as Map).cast<String, dynamic>());
    await p.remove(_clePhotoAEnvoyer);
    notifyListeners();
  });

  /// Retirer la photo de profil : ici et sur le serveur, les initiales partout.
  Future<void> retirerPhoto() => _aLaSuite(() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_clePhotoAEnvoyer);
    if (Api.instance.jeton == null) return;
    final r = await Api.instance.delete('moi/avatar');
    _appliquer((r.json['data'] as Map).cast<String, dynamic>());
    notifyListeners();
  });

  /// Le jeton de ce telephone est retire du serveur, puis tout est oublie ici.
  Future<void> deconnecter() async {
    if (Api.instance.jeton != null) {
      try {
        await Api.instance.post('auth/deconnexion');
      } catch (_) {}
    }
    _vider();
  }

  /// Supprime le compte : le serveur l efface dans 30 jours (se reconnecter
  /// avant l annule). Le message du serveur dit la date.
  Future<String?> supprimerCompte() async {
    String? message;
    if (Api.instance.jeton != null) {
      final r = await Api.instance.delete('moi');
      message = r.json['message'] as String?;
    }
    _vider();
    return message;
  }

  void _vider() {
    Api.instance.garderJeton(null);
    Verrou.instance.fermer();
    SharedPreferences.getInstance()
        .then(
          (p) => p
            ..remove(_cleMembre)
            ..remove(_cleProfilAEnvoyer)
            ..remove(_clePhotoAEnvoyer)
            ..remove(clePhotoProfil),
        )
        .ignore();
    connecte = false;
    profilComplete = false;
    email = '';
    nomAffiche = '';
    nomUtilisateur = '';
    bio = '';
    site = '';
    avatar = null;
    // La photo de ce compte ne passe pas au compte suivant sur ce telephone.
    final ancienne = photo;
    photo = null;
    if (ancienne != null) File(ancienne).delete().then((_) {}, onError: (_) {});
    interets.clear();
    Communaute.instance.oublier();
    // L historique de ce compte (envois, publications, telechargements, lieux masques) reste a lui :
    // le compte suivant sur ce telephone ne le voit pas.
    Envois.instance.oublier();
    _proprietaire = null;
    SharedPreferences.getInstance().then((p) => p.remove(_cleHistorique)).ignore();
    MesPublications.instance.oublier();
    Lifestyle.instance.oublier().ignore();
    Telechargements.instance.oublier();
    Catalogue.instance.oublierLeCompte();
    notifyListeners();
  }

  /// Mon nombre d abonnements apres un abonnement : celui du serveur, sinon l ancien plus [ecart].
  void abonnementsConnus(int? serveur, int ecart) {
    final n = serveur ?? (abonnements == null ? null : (abonnements! + ecart).clamp(0, 1 << 30));
    if (n == null || n == abonnements) return;
    abonnements = n;
    notifyListeners();
  }

  void _appliquer(Map<String, dynamic> u, {bool garder = true}) {
    final compteurs = (u['compteurs'] as Map?)?.cast<String, dynamic>();
    if (compteurs != null) {
      abonnes = (compteurs['abonnes'] as num?)?.toInt();
      abonnements = (compteurs['abonnements'] as num?)?.toInt();
      nombreContenus = (compteurs['contenus'] as num?)?.toInt();
    }
    email = u['email'] as String? ?? email;
    nomAffiche = u['nom_affiche'] as String? ?? nomAffiche;
    nomUtilisateur = u['nom_utilisateur'] as String? ?? nomUtilisateur;
    bio = u['bio'] as String? ?? '';
    site = u['site'] as String? ?? '';
    pays = u['pays'] as String? ?? pays;
    ville = u['ville'] as String? ?? ville;
    position = u['position'] as bool? ?? position;
    avatar = u['avatar'] as String?;
    profilComplete = u['profil_complete'] == true;
    google = u['google'] == true;
    interets
      ..clear()
      ..addAll([for (final t in (u['types_aimes'] as List?) ?? const []) t as String]);
    if (garder) {
      SharedPreferences.getInstance().then((p) => p.setString(_cleMembre, jsonEncode(u))).ignore();
    }
    final id = u['id'] as String?;
    if (id != null && id.isNotEmpty) unawaited(_historiqueDe(id));
  }

  static const _cleHistorique = 'historique_de';

  /// Le compte a qui est l historique, une fois verifie dans cette session.
  String? _proprietaire;

  /// L historique garde sur ce telephone (envois, publications, telechargements) est a un seul
  /// compte. Un autre compte connecte (sans deconnexion avant, ou avant cette regle) : il repart
  /// vide, et rien du compte precedent ne s y affiche.
  Future<void> _historiqueDe(String id) async {
    // Une fois par compte : deux profils lus coup sur coup ne vident pas deux fois (le second
    // effacait ce qui venait d etre publie).
    if (_proprietaire == id) return;
    _proprietaire = id;
    try {
      final p = await SharedPreferences.getInstance();
      final avant = p.getString(_cleHistorique);
      if (avant == id) return;
      await p.setString(_cleHistorique, id);
      // Avant cette regle, on ne sait pas a qui il etait : seul un envoi encore en route reste.
      Envois.instance.oublier(garderEnCours: avant == null);
      MesPublications.instance.oublier();
      Lifestyle.instance.oublier().ignore();
      Telechargements.instance.oublier();
      Catalogue.instance.oublierLeCompte();
    } catch (_) {}
  }

  // Le nom propose a « Completer le profil », tire de l adresse.
  void _nomsDepuisEmail() {
    final local = email.split('@').first;
    if (nomUtilisateur.isEmpty) nomUtilisateur = local.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    if (nomAffiche.isEmpty) nomAffiche = _nomDepuis(local);
  }

  String get initiales {
    final mots = nomAffiche.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return 'U';
    return mots.take(2).map((m) => m[0].toUpperCase()).join();
  }

  static String _nomDepuis(String local) {
    final mots = local.split(RegExp(r'[._-]+')).where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return '';
    final premier = mots.first[0].toUpperCase() + mots.first.substring(1);
    return mots.length > 1 ? '$premier ${mots[1][0].toUpperCase()}.' : premier;
  }
}
