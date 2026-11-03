// La communaute (lot 5) cote telephone : reagir, commenter, enregistrer dans
// une collection, suivre, bloquer, signaler, partager, et les notifications.
//
// Chaque geste se voit tout de suite (on n attend pas le serveur), puis part
// au serveur ; s il refuse, l ecran revient en arriere avec son message. Sans
// compte (visiteur), rien ne change : l ecran invite a se connecter.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../outils/api.dart';
import '../outils/langue.dart';
import 'modeles.dart';
import 'session.dart';

/// Les quatre reactions de Discover : la cle du serveur et ce qui s affiche.
const reactions = {'coeur': '❤️', 'waouh': '🤩', 'voyage': '🧳', 'merci': '🙏'};

/// Un commentaire tel que le serveur le donne.
class CommentaireServeur {
  CommentaireServeur({
    required this.id,
    required this.texte,
    required this.pseudo,
    required this.nom,
    required this.avatar,
    required this.quand,
    required this.jaime,
    required this.reponses,
    required this.epingle,
    required this.deLAuteur,
    required this.aimeParMoi,
    required this.mien,
    this.repondA,
    this.parent,
    this.modifie = false,
  });

  factory CommentaireServeur.depuis(Map<String, dynamic> j) {
    final a = (j['auteur'] as Map?)?.cast<String, dynamic>() ?? const {};
    final r = (j['repond_a'] as Map?)?.cast<String, dynamic>();
    final moi = (j['moi'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CommentaireServeur(
      id: j['id'] as String,
      texte: j['texte'] as String? ?? '',
      pseudo: a['nom_utilisateur'] as String? ?? '',
      nom: (a['nom_affiche'] as String?) ?? (a['nom_utilisateur'] as String? ?? ''),
      avatar: a['avatar'] as String?,
      quand: DateTime.tryParse(j['cree_le'] as String? ?? '') ?? DateTime.now(),
      jaime: (j['jaime'] as num?)?.toInt() ?? 0,
      reponses: (j['reponses'] as num?)?.toInt() ?? 0,
      epingle: j['epingle'] == true,
      deLAuteur: j['de_l_auteur'] == true,
      aimeParMoi: moi['jaime'] == true,
      mien: moi['auteur'] == true,
      repondA: r == null ? null : ((r['nom_affiche'] as String?) ?? r['nom_utilisateur'] as String?),
      parent: j['parent'] as String?,
      modifie: j['modifie'] == true,
    );
  }

  final String id;
  final String texte;
  final String pseudo;
  final String nom;
  final String? avatar;
  final DateTime quand;
  final int jaime;
  final int reponses;
  final bool epingle;
  final bool deLAuteur;
  final bool aimeParMoi;
  final bool mien;
  final String? repondA;
  final String? parent;

  /// Retouche par son auteur apres coup.
  final bool modifie;
}

/// Une collection du membre (E19).
class CollectionServeur {
  const CollectionServeur({required this.id, required this.nom, required this.secrete, required this.nombre, required this.couverture});

  factory CollectionServeur.depuis(Map<String, dynamic> j) => CollectionServeur(
    id: j['id'] as String,
    nom: j['nom'] as String? ?? '',
    secrete: j['secrete'] == true,
    nombre: (j['nombre_contenus'] as num?)?.toInt() ?? 0,
    couverture: [for (final u in (j['couverture'] as List? ?? [])) u as String],
  );

  final String id;
  final String nom;
  final bool secrete;
  final int nombre;
  final List<String> couverture;
}

/// Une notification (E17).
class NotificationServeur {
  const NotificationServeur({
    required this.id,
    required this.genre,
    required this.texte,
    required this.quand,
    required this.lue,
    this.acteur,
    this.acteurPseudo,
    this.avatar,
    this.contenu,
    this.lieu,
    this.photo,
    this.commentaire,
    this.ton,
    this.typeContenu,
    this.badge,
  });

  factory NotificationServeur.depuis(Map<String, dynamic> j) {
    final a = (j['acteur'] as Map?)?.cast<String, dynamic>();
    final c = (j['contenu'] as Map?)?.cast<String, dynamic>();
    return NotificationServeur(
      id: j['id'] as String,
      genre: j['genre'] as String? ?? '',
      ton: j['ton'] as String?,
      texte: j['texte'] as String? ?? '',
      quand: DateTime.tryParse(j['cree_le'] as String? ?? '') ?? DateTime.now(),
      lue: j['lue'] == true,
      acteur: a == null ? null : ((a['nom_affiche'] as String?) ?? a['nom_utilisateur'] as String?),
      acteurPseudo: a?['nom_utilisateur'] as String?,
      avatar: a?['avatar'] as String?,
      contenu: c?['id'] as String?,
      lieu: c?['lieu'] as String?,
      photo: c?['photo'] as String?,
      typeContenu: c?['type'] as String?,
      badge: c?['badge'] as String?,
      commentaire: j['commentaire'] as String?,
    );
  }

  final String id;
  final String genre;
  final String texte;

  /// Un message de l equipe : felicitations, avertissement ou info.
  final String? ton;
  final DateTime quand;
  final bool lue;
  final String? acteur;
  final String? acteurPseudo;
  final String? avatar;
  final String? contenu;
  final String? lieu;
  final String? photo;
  final String? commentaire;

  /// photo ou reel, pour la publication concernee.
  final String? typeContenu;

  /// Le badge de la publication aujourd hui (verifiee, declaree), nul sans publication.
  final String? badge;
}

/// « maintenant », « 5 min », « 3 h », « 2 j », « 4 sem ».
String ilYA(DateTime d) {
  final e = DateTime.now().difference(d);
  if (e.inMinutes < 1) return t('maintenant');
  if (e.inHours < 1) return t('{n} min', {'n': e.inMinutes});
  if (e.inDays < 1) return t('{n} h', {'n': e.inHours});
  if (e.inDays < 7) return t('{n} j', {'n': e.inDays});
  return t('{n} sem.', {'n': e.inDays ~/ 7});
}

class Communaute extends ChangeNotifier {
  Communaute._();
  static final instance = Communaute._();

  /// Un compte sur le serveur : les gestes y partent. Un visiteur est invite a se connecter.
  bool get enLigne => Api.instance.jeton != null;

  /// Ma reaction sur chaque contenu (une fois connue : du serveur ou de mon geste).
  final _reactions = <String, String?>{};

  /// Les createurs que je suis (leurs pseudos).
  final suivis = <String>{};
  final bloques = <String>{};
  final enregistres = <String>{};

  List<CollectionServeur>? collections;
  int nonLues = 0;

  /// Mes collections sur le serveur (aucune avant sa reponse, ou sans compte).
  List<Collection> get mesCollections => [for (final x in collections ?? const <CollectionServeur>[]) Collection(id: x.id, nom: x.nom, secrete: x.secrete, nombre: x.nombre, photos: x.couverture)];

  // ------------------------------------------------------------ au demarrage

  /// Ce qui se garde d une session a l autre : qui je suis, mes collections, mes notifications non lues.
  Future<void> charger() async {
    if (!enLigne) return;
    try {
      final r = await Api.instance.get('moi/abonnements');
      suivis
        ..clear()
        ..addAll([for (final m in (r.json['data'] as List? ?? []).cast<Map>()) m['nom_utilisateur'] as String]);
    } catch (_) {}
    await chargerCollections();
    await rafraichirNonLues();
    notifyListeners();
  }

  void oublier() {
    _reactions.clear();
    _jaimeConnus.clear();
    suivis.clear();
    bloques.clear();
    enregistres.clear();
    collections = null;
    nonLues = 0;
    notifyListeners();
  }

  // ------------------------------------------------------------ reactions

  String? reactionSur(String id, {String? duServeur}) => _reactions.containsKey(id) ? _reactions[id] : duServeur;

  /// Le dernier nombre de reactions rendu par le serveur apres mon geste, et si j en etais.
  final _jaimeConnus = <String, ({int n, bool moi})>{};

  /// Le nombre de reactions a montrer. Il part d un nombre du serveur et de ma reaction *dans ce
  /// meme etat* (`moiDuServeur`), jamais de ma reaction retenue ici : une publication gardee
  /// d avant mon « j aime » montrait 0 avec un coeur rouge, puis -1 en le retirant. Jamais < 0.
  int nombreReactions(String? contenu, {required int duServeur, required bool moiDuServeur}) {
    final connu = contenu == null ? null : _jaimeConnus[contenu];
    final base = connu?.n ?? duServeur;
    final moiBase = connu?.moi ?? moiDuServeur;
    final moi = contenu == null ? moiDuServeur : reactionSur(contenu, duServeur: moiDuServeur ? 'coeur' : null) != null;
    final n = base + (moi ? 1 : 0) - (moiBase ? 1 : 0);
    return n < 0 ? 0 : n;
  }

  /// Reagir (ou changer de reaction) ; `type` nul : la retirer. Vrai si le serveur l a pris.
  Future<bool> reagir(String? contenu, String? type) async {
    if (contenu == null || !enLigne) return true;
    final avant = _reactions[contenu];
    _reactions[contenu] = type;
    notifyListeners();
    Future<Reponse> envoyer() async {
      final r = type == null ? await Api.instance.delete('contenus/$contenu/reaction') : await Api.instance.put('contenus/$contenu/reaction', {'type': type});
      // Le nombre exact, avec mon geste : il remplace le calcul, partout ou il s affiche.
      final n = (r.json['reactions'] as num?)?.toInt();
      if (n != null && _reactions[contenu] == type) {
        _jaimeConnus[contenu] = (n: n, moi: type != null);
        notifyListeners();
      }
      return r;
    }

    final cle = 'reaction:$contenu';
    Api.instance.oublierEnAttente(cle);
    try {
      await envoyer();
      return true;
    } catch (e) {
      // Pas de reseau, ou le serveur qui se met a jour : le coeur reste, il part des que possible.
      if (Api.passager(e)) {
        Api.instance.plusTard(cle, envoyer);
        return true;
      }
      _reactions[contenu] = avant;
      notifyListeners();
      return false;
    }
  }

  /// Qui a reagi : le total de chaque reaction, et les membres (30 par page ; `suivant` : la page d apres).
  Future<({Map<String, int> totaux, int total, List<(String pseudo, String nom, String? avatar, String type, bool abonne)> membres, String? suivant})?> quiAReagi(
    String contenu, {
    String? type,
    String? curseur,
  }) async {
    try {
      final q = [if (type != null) 'type=$type', if (curseur != null) 'curseur=${Uri.encodeQueryComponent(curseur)}'];
      final r = await Api.instance.get('contenus/$contenu/reactions${q.isEmpty ? '' : '?${q.join('&')}'}');
      return (
        suivant: (r.json['meta'] as Map?)?['next_cursor'] as String?,
        totaux: {for (final e in ((r.json['totaux'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()},
        total: (r.json['total'] as num?)?.toInt() ?? 0,
        membres: [
          for (final m in (r.json['data'] as List? ?? []).cast<Map>())
            (
              (m['membre'] as Map)['nom_utilisateur'] as String? ?? '',
              ((m['membre'] as Map)['nom_affiche'] as String?) ?? ((m['membre'] as Map)['nom_utilisateur'] as String? ?? ''),
              (m['membre'] as Map)['avatar'] as String?,
              m['type'] as String? ?? 'coeur',
              m['abonne'] == true,
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ commentaires

  /// Le nombre de commentaires des publications ouvertes, tenu a jour a chaque ajout ou
  /// suppression : la feuille, la page de la photo et les reels le montrent en meme temps.
  /// [vu] : le nombre du serveur d ou il part. Tant que le serveur redonne ce nombre (sa copie
  /// d avant mes gestes), le mien fait foi ; un autre nombre du serveur, plus recent, le remplace.
  final _nbCommentaires = <String, ({int vu, int n})>{};

  /// Les commentaires que je viens de retirer : ils disparaissent aussi de la page de la photo.
  final commentairesRetires = <String>{};

  /// Chaque ajout ou retrait de commentaire sur une publication change sa version.
  final _versionCommentaires = <String, int>{};

  int versionCommentaires(String contenu) => _versionCommentaires[contenu] ?? 0;

  /// Le nombre a montrer : celui tenu a jour, sinon celui du serveur.
  int nombreCommentaires(String? contenu, int duServeur) {
    final c = contenu == null ? null : _nbCommentaires[contenu];
    return c != null && c.vu == duServeur ? c.n : duServeur;
  }

  /// Le nombre donne par le serveur a l ouverture d une page ou d une feuille.
  void connaitreCommentaires(String contenu, int duServeur) {
    if (_nbCommentaires[contenu]?.vu != duServeur) _nbCommentaires[contenu] = (vu: duServeur, n: duServeur);
  }

  void _commentairesChangent(String contenu, int ecart, {String? retire}) {
    final c = _nbCommentaires[contenu] ?? (vu: -1, n: 0);
    final n = c.n + ecart;
    _nbCommentaires[contenu] = (vu: c.vu, n: n < 0 ? 0 : n);
    if (retire != null) commentairesRetires.add(retire);
    _versionCommentaires[contenu] = versionCommentaires(contenu) + 1;
    notifyListeners();
  }

  /// Mes commentaires (pas les reponses) envoyes depuis l ouverture : la page de la photo les
  /// montre tout de suite, avant de les relire du serveur. Le provisoire est remplace par celui
  /// du serveur des qu il repond ; une lecture qui les contient les retire d ici.
  final _envoyes = <String, List<CommentaireServeur>>{};

  List<CommentaireServeur> envoyes(String contenu) => _envoyes[contenu] ?? const [];

  /// Un commentaire ajoute : le nombre monte tout de suite (il redescend si l envoi echoue), et
  /// `provisoire` (un commentaire, pas une reponse) s affiche deja sur la page.
  void commentaireAjoute(String contenu, {CommentaireServeur? provisoire}) {
    if (provisoire != null) (_envoyes[contenu] ??= []).insert(0, provisoire);
    _commentairesChangent(contenu, 1);
  }

  /// Le serveur a pris mon commentaire : le sien remplace le provisoire.
  void commentaireConfirme(String contenu, CommentaireServeur provisoire, CommentaireServeur c) {
    final liste = _envoyes[contenu];
    final i = liste?.indexOf(provisoire) ?? -1;
    if (i < 0) return;
    liste![i] = c;
    notifyListeners();
  }

  /// Un envoi que le serveur a refuse : le nombre redescend, le provisoire part.
  void commentaireAnnule(String contenu, {CommentaireServeur? provisoire}) {
    _envoyes[contenu]?.remove(provisoire);
    _commentairesChangent(contenu, -1);
  }

  /// Un retrait que le serveur a refuse : le commentaire et ses reponses reviennent.
  void commentaireRendu(String contenu, String id, {int reponses = 0}) {
    commentairesRetires.remove(id);
    _commentairesChangent(contenu, 1 + reponses);
  }

  /// Un commentaire retire, avec ses reponses : il part tout de suite, partout.
  void commentaireRetire(String contenu, String id, {int reponses = 0}) => _commentairesChangent(contenu, -1 - reponses, retire: id);

  Future<List<CommentaireServeur>?> commentaires(String contenu) async {
    try {
      final r = await Api.instance.get('contenus/$contenu/commentaires');
      final liste = [for (final c in (r.json['data'] as List? ?? []).cast<Map>()) CommentaireServeur.depuis(c.cast<String, dynamic>())];
      // Relus du serveur : mes commentaires envoyes n ont plus a etre gardes a part.
      final ids = {for (final c in liste) c.id};
      _envoyes[contenu]?.removeWhere((c) => ids.contains(c.id));
      return liste;
    } catch (_) {
      return null;
    }
  }

  Future<List<CommentaireServeur>?> reponses(String commentaire) async {
    try {
      final r = await Api.instance.get('commentaires/$commentaire/reponses');
      return [for (final c in (r.json['data'] as List? ?? []).cast<Map>()) CommentaireServeur.depuis(c.cast<String, dynamic>())];
    } catch (_) {
      return null;
    }
  }

  /// Commenter, ou repondre a `parent`. Leve ErreurApi (son message s affiche) ou ApiInjoignable.
  Future<CommentaireServeur> commenter(String contenu, String texte, {String? parent}) async {
    final r = await Api.instance.post('contenus/$contenu/commentaires', {'texte': texte, 'parent': ?parent});
    return CommentaireServeur.depuis((r.json['data'] as Map).cast<String, dynamic>());
  }

  /// Vrai si le serveur l a pris.
  Future<bool> aimerCommentaire(String commentaire, bool aime) async {
    if (!enLigne) return false;
    try {
      aime ? await Api.instance.put('commentaires/$commentaire/jaime', {}) : await Api.instance.delete('commentaires/$commentaire/jaime');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mon commentaire, retouche : le texte que le serveur garde, ou nul en cas d echec.
  Future<CommentaireServeur?> modifierCommentaire(String commentaire, String texte) async {
    try {
      final r = await Api.instance.patch('commentaires/$commentaire', {'texte': texte});
      return CommentaireServeur.depuis((r.json['data'] as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<bool> supprimerCommentaire(String commentaire) async {
    try {
      await Api.instance.delete('commentaires/$commentaire');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> epingler(String commentaire) async {
    try {
      final r = await Api.instance.post('commentaires/$commentaire/epingle', {});
      return r.json['epingle'] == true;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ collections

  Future<void> chargerCollections() async {
    if (!enLigne) return;
    try {
      final r = await Api.instance.get('collections');
      collections = [for (final c in (r.json['data'] as List? ?? []).cast<Map>()) CollectionServeur.depuis(c.cast<String, dynamic>())];
      notifyListeners();
    } catch (_) {}
  }

  /// Creer une collection (et y enregistrer `contenu`, s il y en a un). Leve ErreurApi (un nom deja pris).
  Future<CollectionServeur> creerCollection(String nom, {bool secrete = false, String? contenu}) async {
    final r = await Api.instance.post('collections', {'nom': nom, 'secrete': secrete});
    var c = CollectionServeur.depuis((r.json['data'] as Map).cast<String, dynamic>());
    if (contenu != null) c = await enregistrer(c.id, contenu) ?? c;
    await chargerCollections();
    return c;
  }

  Future<CollectionServeur?> enregistrer(String collection, String contenu, {bool retirer = false}) async {
    try {
      final r = retirer ? await Api.instance.delete('collections/$collection/contenus/$contenu') : await Api.instance.put('collections/$collection/contenus/$contenu', {});
      retirer ? enregistres.remove(contenu) : enregistres.add(contenu);
      unawaited(chargerCollections());
      return CollectionServeur.depuis((r.json['collection'] as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<bool> modifierCollection(String collection, {String? nom, bool? secrete}) async {
    try {
      await Api.instance.patch('collections/$collection', {'nom': ?nom, 'secrete': ?secrete});
      await chargerCollections();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> supprimerCollection(String collection) async {
    try {
      await Api.instance.delete('collections/$collection');
      await chargerCollections();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Les publications d une collection, telles que le serveur les donne (JSON brut, lu par le catalogue).
  Future<List<Map<String, dynamic>>?> contenusDe(String collection) async {
    try {
      final r = await Api.instance.get('collections/$collection/contenus');
      return [for (final c in (r.json['data'] as List? ?? []).cast<Map>()) c.cast<String, dynamic>()];
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ suivre, bloquer

  bool suit(String pseudo) => suivis.contains(pseudo.replaceFirst('@', ''));

  /// Suivre (ou ne plus suivre). Renvoie le nouveau nombre d abonnes, ou nul si le serveur a refuse ; -1 sans compte (rien ne change).
  Future<int?> suivre(String pseudo, bool oui) async {
    final p = pseudo.replaceFirst('@', '');
    if (!enLigne) return -1;
    oui ? suivis.add(p) : suivis.remove(p);
    notifyListeners();
    Future<Reponse> envoyer() async {
      final r = oui ? await Api.instance.put('utilisateurs/$p/abonnement', {}) : await Api.instance.delete('utilisateurs/$p/abonnement');
      // Mon profil compte mes abonnements tout de suite, sans attendre la prochaine ouverture.
      Session.instance.abonnementsConnus((r.json['mes_abonnements'] as num?)?.toInt(), oui ? 1 : -1);
      return r;
    }

    final cle = 'abonnement:$p';
    Api.instance.oublierEnAttente(cle);
    try {
      return ((await envoyer()).json['abonnes'] as num?)?.toInt();
    } catch (e) {
      // Pas de reseau, ou le serveur qui se met a jour : l abonnement reste, il part des que possible.
      if (Api.passager(e)) {
        Api.instance.plusTard(cle, envoyer);
        Session.instance.abonnementsConnus(null, oui ? 1 : -1);
        return -1;
      }
      oui ? suivis.remove(p) : suivis.add(p);
      notifyListeners();
      return null;
    }
  }

  /// Mes comptes bloques (nom, pseudo, photo) ; nul hors ligne ou sans compte.
  Future<List<(String nom, String pseudo, String? avatar)>?> mesBlocages() async {
    if (!enLigne) return null;
    try {
      final r = await Api.instance.get('moi/blocages');
      final liste = [
        for (final m in (r.json['data'] as List? ?? []).cast<Map>())
          (((m['nom_affiche'] as String?) ?? (m['nom_utilisateur'] as String? ?? '')), m['nom_utilisateur'] as String? ?? '', m['avatar'] as String?),
      ];
      bloques
        ..clear()
        ..addAll([for (final b in liste) b.$2]);
      return liste;
    } catch (_) {
      return null;
    }
  }

  /// Bloquer (ou debloquer). Renvoie le message du serveur, ou nul s il a echoue (ou sans compte).
  Future<String?> bloquer(String pseudo, bool oui) async {
    final p = pseudo.replaceFirst('@', '');
    if (!enLigne) return null;
    try {
      final r = oui ? await Api.instance.put('utilisateurs/$p/blocage', {}) : await Api.instance.delete('utilisateurs/$p/blocage');
      oui ? bloques.add(p) : bloques.remove(p);
      if (oui) suivis.remove(p);
      notifyListeners();
      return (r.json['message'] as String?) ?? (oui ? t('Compte bloqué.') : t('Compte débloqué.'));
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ signaler, partager

  /// `cible` : contenu, utilisateur ou commentaire. Renvoie le message a montrer.
  Future<String> signaler(String cible, String id, String motif, {String? precision}) async {
    if (!enLigne) return t('Connectez-vous pour signaler.');
    try {
      final r = await Api.instance.post('signalements', {'cible': cible, 'id': id, 'motif': motif, 'precision': ?precision});
      return (r.json['message'] as String?) ?? t('Merci. Votre signalement a été envoyé.');
    } on ErreurApi catch (e) {
      return e.message;
    } catch (_) {
      return t('Aucune connexion. Réessayez dans un instant.');
    }
  }

  Future<void> partager(String? contenu) async {
    if (contenu == null) return;
    try {
      await Api.instance.post('contenus/$contenu/partage', {});
    } catch (_) {}
  }

  // ------------------------------------------------------------ notifications

  Future<void> rafraichirNonLues() async {
    if (!enLigne) return;
    try {
      final r = await Api.instance.get('notifications');
      nonLues = (r.json['non_lues'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  /// Mes notifications, 30 par page (`curseur` : la page d apres) ; nul hors ligne ou sans compte.
  Future<({List<NotificationServeur> liste, String? suivant})?> notifications({String? curseur}) async {
    if (!enLigne) return null;
    try {
      final r = await Api.instance.get('notifications${curseur == null ? '' : '?curseur=${Uri.encodeQueryComponent(curseur)}'}');
      nonLues = (r.json['non_lues'] as num?)?.toInt() ?? 0;
      notifyListeners();
      return (
        liste: [for (final n in (r.json['data'] as List? ?? []).cast<Map>()) NotificationServeur.depuis(n.cast<String, dynamic>())],
        suivant: (r.json['meta'] as Map?)?['next_cursor'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ma publication refusee : une seconde verification par l equipe (une seule fois).
  /// Renvoie le code du serveur (200 : partie ; 422 : deja demandee ou plus refusee ; 0 : pas de reseau) et son message.
  Future<(int, String)> demanderVerification(String contenu) async {
    if (!enLigne) return (401, t('Connectez-vous pour demander une vérification.'));
    try {
      final r = await Api.instance.post('contenus/$contenu/verification', {});
      return (200, (r.json['message'] as String?) ?? t('Demande envoyée. Vous recevrez une notification dès que la décision sera prise.'));
    } on ErreurApi catch (e) {
      return (e.code, e.message);
    } catch (_) {
      return (0, t('Aucune connexion. Réessayez dans un instant.'));
    }
  }

  /// Retirer une notification de la liste ; faux si le serveur ne l a pas pris.
  Future<bool> supprimerNotification(String id) async {
    if (!enLigne) return false;
    try {
      final r = await Api.instance.delete('notifications/${Uri.encodeComponent(id)}');
      nonLues = (r.json['non_lues'] as num?)?.toInt() ?? nonLues;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toutLu() async {
    if (!enLigne) return;
    try {
      final r = await Api.instance.post('notifications/lues', {});
      nonLues = (r.json['non_lues'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {}
  }
}
