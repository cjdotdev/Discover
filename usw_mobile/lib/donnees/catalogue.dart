// Ce que Discover montre (lot 4) : les lieux de l accueil, leurs publications,
// les reels, les createurs, la recherche, tels que le serveur les donne
// (usw_api, /api/v1/flux/decouverte, /reels, /lieux/…, /recherche…).
//
// Le telephone garde la derniere page recue (catalogue.json) : Discover s ouvre
// tout de suite, et hors ligne il montre ce qu il a deja vu, comme les photos
// gardees par ImagesReseau. Sans rien de tout cela (premier lancement sans
// reseau), les ecrans attendent le reseau et le disent (horsLigne).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/api.dart';
import '../outils/images_reseau.dart';
import '../outils/langue.dart';
import 'capture.dart';
import 'modeles.dart';

class Catalogue extends ChangeNotifier {
  Catalogue._();
  static final instance = Catalogue._();

  /// Les lieux de Decouverte, dans l ordre du serveur (nul : rien recu encore).
  List<Lieu>? _lieux;
  String? _curseur;
  bool _fin = false;
  bool _chargement = false;

  /// Tous les lieux rencontres (accueil, recherche, reels, createurs), par leur id.
  final _connus = <String, Lieu>{};

  /// Les publications de chaque lieu ; `_completes` : la liste entiere est arrivee.
  final _publications = <String, List<Publication>>{};
  final _completes = <String>{};
  final _parId = <String, Publication>{};

  List<Reel>? _reels;
  String? _curseurReels;
  bool _finReels = false;

  final _createurs = <String, Createur>{};

  ({double latitude, double longitude})? _position;
  List<Lieu>? _avecDistances;

  /// Les donnees viennent du serveur (en direct, ou gardees de la derniere fois).
  bool get duServeur => _lieux != null;

  /// Rien recu, et le serveur ne repond pas : les ecrans proposent de reessayer.
  bool horsLigne = false;

  /// La fin de Decouverte est atteinte : plus rien a charger en bas de l accueil.
  bool get fin => _fin || !duServeur;

  // ------------------------------------------------------------ ce que les ecrans lisent

  /// Les lieux de l accueil, de la carte, de la recherche, avec leur distance
  /// (sans ceux que le membre a masques).
  List<Lieu> get lieux {
    final base = _lieux ?? const <Lieu>[];
    final tous = _position == null || !duServeur ? base : _avecDistances ??= [for (final l in base) l.situe ? l.aDistance(_km(l)) : l];
    return masques.isEmpty
        ? tous
        : [
            for (final l in tous)
              if (!masques.contains(l.id)) l,
          ];
  }

  /// Les lieux masques (« Voir moins ») : ils quittent l accueil, sur ce telephone.
  final masques = <String>{};

  static const _cleMasques = 'lieux_masques';

  void masquer(String id, {bool oui = true}) {
    oui ? masques.add(id) : masques.remove(id);
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setStringList(_cleMasques, masques.toList())).ignore();
  }

  /// Les publications supprimees depuis ce telephone : les listes deja recues
  /// (mon profil, un createur) ne les montrent plus, sans attendre le serveur.
  final supprimees = <String>{};

  /// Une publication supprimee : elle quitte les piles, les reels et la recherche, tout de suite.
  /// « Pas intéressé » : la publication sort de mes fils tout de suite, et le serveur
  /// l ecarte de « Pour toi » (son createur y passe moins souvent).
  void pasInteresse(String id) {
    oublierPublication(id);
    Api.instance.post('contenus/${Uri.encodeComponent(id)}/pas-interesse').ignore();
  }

  void oublierPublication(String id) {
    supprimees.add(id);
    final partie = _parId.remove(id);
    // Sa photo quitte la pile de son lieu ; une pile vide quitte l accueil.
    final lieux = _lieux;
    if (partie != null && lieux != null) {
      _lieux = [
        for (final l in lieux)
          if (!l.photos.contains(partie.photo))
            l
          else if (l.nombre > 1 && l.photos.length > 1)
            Lieu(
              id: l.id,
              nom: l.nom,
              region: l.region,
              photos: [
                for (final ph in l.photos)
                  if (ph != partie.photo) ph,
              ],
              nombre: l.nombre - 1,
              ratio: l.ratio,
              type: l.type,
              latitude: l.latitude,
              longitude: l.longitude,
              distanceKm: l.distanceKm,
              situe: l.situe,
            ),
      ];
      _avecDistances = null;
    }
    _publications.updateAll(
      (_, liste) => [
        for (final p in liste)
          if (p.id != id) p,
      ],
    );
    _reels?.removeWhere((r) => r.id == id);
    notifyListeners();
    unawaited(rafraichir());
  }

  Lieu? lieu(String id) {
    final l = _connus[id];
    if (l == null) return null;
    return _position == null || !l.situe ? l : l.aDistance(_km(l));
  }

  int _km(Lieu l) {
    final p = _position!;
    return (_distanceKm(p.latitude, p.longitude, l.latitude, l.longitude)).round();
  }

  /// Les publications d un lieu. La premiere lecture lance le chargement de la liste entiere.
  List<Publication> publicationsDe(Lieu lieu) {
    if (_connus.containsKey(lieu.id) && !_completes.contains(lieu.id)) scheduleMicrotask(() => chargerContenus(lieu.id));
    return _publications[lieu.id] ?? const [];
  }

  Publication? publication(String id) => _parId[id];

  /// Vrai si cette publication est deja dans une pile de l accueil, venue du serveur : ma
  /// copie gardee sur le telephone ne s y montre plus en double.
  bool aLAccueil(String contenu) => lieux.any((l) => dansLaPile(l.id, contenu));

  /// Vrai si la pile de ce lieu, venue du serveur, montre deja cette publication.
  bool dansLaPile(String lieu, String contenu) => (_publications[lieu] ?? const <Publication>[]).any((p) => p.id == contenu);

  /// n photos des lieux recus, pour habiller la bienvenue et l entree, en [colonnes] colonnes
  /// (rangees colonne apres colonne) : deux voisines ne viennent pas du meme lieu (disposerVitrine).
  /// Les videos y passent aussi, par leur affiche (elles s y lisent : videosDesAffiches).
  /// Une photo pas encore sur le telephone laisse sa place a une image du paquet, qu elle
  /// remplace des qu elle arrive : a ecouter avec ImagesReseau.pretes.
  List<String> vitrine(int n, {int colonnes = 1}) {
    final photos = _vitrine(n, colonnes);
    return [
      for (var i = 0; i < n; i++)
        if (photos[i].startsWith('assets/') || ImagesReseau.pretes.contient(photos[i])) photos[i] else _secours[i % _secours.length],
    ];
  }

  /// Une publication des premiers lieux avec son telephone et sa date de prise, pour la
  /// bienvenue : verifiee d abord, sinon declaree par son auteur. Leurs publications se
  /// chargent a la premiere lecture.
  (Publication, Lieu)? exempleDeCapture() {
    (Publication, Lieu)? declaree;
    for (final l in lieux.take(3)) {
      for (final p in publicationsDe(l)) {
        if (p.reel || p.appareil.isEmpty || p.priseLe == null) continue;
        if (p.verifiee) return (p, l);
        declaree ??= (p, l);
      }
    }
    return declaree;
  }

  /// Les photos des gouts proposes a l inscription, livrees avec l application.
  static final _secours = [for (final g in themesAimes) 'assets/interets/${g.cle}.webp'];

  List<String> _vitrine(int n, int colonnes) {
    final vues = <String>{};
    return disposerVitrine(
      [
        for (final l in lieux)
          for (final p in l.photos)
            if (p.isNotEmpty && vues.add(p)) (photo: p, lieu: l.id),
        for (final r in reels)
          if (r.photo.isNotEmpty && vues.add(r.photo)) (photo: r.photo, lieu: r.lieu),
      ],
      n,
      colonnes,
    );
  }

  /// La photo d un lieu de ce type, s il y en a un (sinon une case vide).
  String photoDuType(String type) => lieux.where((l) => l.type == type && l.photos.isNotEmpty).firstOrNull?.photos.first ?? '';

  List<Reel> get reels => _reels ?? const [];

  bool get finReels => _finReels || _reels == null;

  // ------------------------------------------------------------ au demarrage

  Future<File> _fichier() async => File('${(await getApplicationSupportDirectory()).path}/catalogue.json');

  /// La copie gardee d abord (instantane, hors ligne), puis le serveur.
  Future<void> demarrer() async {
    try {
      masques.addAll((await SharedPreferences.getInstance()).getStringList(_cleMasques) ?? const []);
    } catch (_) {}
    try {
      final f = await _fichier();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _lieux = [for (final l in (j['lieux'] as List? ?? [])) ?_lieuDe((l as Map).cast<String, dynamic>())];
        _reels = [for (final r in (j['reels'] as List? ?? [])) _reelDe((r as Map).cast<String, dynamic>())];
        _curseur = null;
        _fin = false;
        notifyListeners();
        _prechaufferVitrine();
      }
    } catch (_) {}
    unawaited(_trouverPosition());
    await rafraichir();
  }

  /// Quand la position a ete lue pour la derniere fois (les distances partent d elle).
  DateTime? _positionLue;

  /// La position relue si elle date de plus de 2 minutes (retour dans l application).
  void repositionner() {
    // Rien recu encore (une reponse perdue en route) : on redemande, plutot qu un logo qui tourne.
    if (_lieux == null) unawaited(rafraichir());
    final lue = _positionLue;
    if (lue == null || DateTime.now().difference(lue).inMinutes >= 2) unawaited(_trouverPosition());
  }

  Future<void> _trouverPosition() async {
    try {
      final p = await positionActuelle(demander: false);
      if (p == null) return;
      _positionLue = DateTime.now();
      _position = (latitude: p.latitude, longitude: p.longitude);
      _avecDistances = null;
      notifyListeners();
    } catch (_) {}
  }

  /// Change a chaque changement de compte : une reponse demandee pour l ancien est ignoree.
  int _generation = 0;

  /// La premiere page de Decouverte et des reels, a neuf (tirer pour actualiser).
  Future<void> rafraichir() async {
    final generation = _generation;
    // Les deux a la fois : l accueil s affiche des que ses lieux arrivent, sans attendre les reels.
    final demandeReels = Api.instance.get('reels');
    unawaited(demandeReels.then((_) {}, onError: (_) {}));
    try {
      final r = await Api.instance.get('flux/decouverte');
      if (generation != _generation) return;
      final lieux = (r.json['data'] as List? ?? []).cast<Map>();
      _lieux = [for (final l in lieux) ?_lieuDe(l.cast<String, dynamic>())];
      _curseur = (r.json['meta'] as Map?)?['next_cursor'] as String?;
      _fin = _curseur == null;
      _avecDistances = null;
      notifyListeners();
      _prechaufferVitrine();
      final rr = await demandeReels;
      if (generation != _generation) return;
      final reels = (rr.json['data'] as List? ?? []).cast<Map>();
      _reels = [for (final x in reels) _reelDe(x.cast<String, dynamic>())];
      _curseurReels = (rr.json['meta'] as Map?)?['next_cursor'] as String?;
      _finReels = _curseurReels == null;
      horsLigne = false;
      notifyListeners();
      unawaited(_garder(lieux, reels));
    } catch (_) {
      if (generation != _generation) return;
      // Hors ligne, ou le serveur repond mal : on garde la copie, s il y en a une.
      horsLigne = true;
      notifyListeners();
    }
  }

  // Sans compte, la bienvenue et la page de connexion montrent ces photos : elles se gardent sur
  // le telephone pendant l ecran d accueil, et s affichent aussitot.
  void _prechaufferVitrine() {
    if (Api.instance.jeton != null) return;
    for (final p in {..._vitrine(6, 1), ..._vitrine(15, 3)}) {
      if (p.startsWith('http')) ImagesReseau.octets(p).then((_) {}, onError: (_) {});
    }
    // La photo d exemple de la bienvenue (le telephone, la date et le lieu de la prise).
    for (final l in lieux.take(3)) {
      chargerContenus(l.id).then((_) {
        final photo = exempleDeCapture()?.$1.photo ?? '';
        if (photo.startsWith('http')) ImagesReseau.octets(photo).then((_) {}, onError: (_) {});
      }, onError: (_) {});
    }
  }

  Future<void> _garder(List<Map> lieux, List<Map> reels) async {
    try {
      await (await _fichier()).writeAsString(jsonEncode({'lieux': lieux, 'reels': reels, 'garde_le': DateTime.now().toIso8601String()}));
    } catch (_) {}
  }

  /// La page suivante de Decouverte (le bas de l accueil approche).
  Future<void> suite() async {
    if (_chargement || _fin || _curseur == null) return;
    _chargement = true;
    try {
      final r = await Api.instance.get('flux/decouverte?curseur=${Uri.encodeQueryComponent(_curseur!)}');
      _lieux = [..._lieux ?? const [], for (final l in (r.json['data'] as List? ?? []).cast<Map>()) ?_lieuDe(l.cast<String, dynamic>())];
      _curseur = (r.json['meta'] as Map?)?['next_cursor'] as String?;
      _fin = _curseur == null;
      _avecDistances = null;
      notifyListeners();
    } catch (_) {
    } finally {
      _chargement = false;
    }
  }

  /// Les reels suivants (le fil approche de sa fin).
  Future<void> suiteReels() async {
    if (_finReels || _curseurReels == null) return;
    final curseur = _curseurReels!;
    _curseurReels = null;
    try {
      final r = await Api.instance.get('reels?curseur=${Uri.encodeQueryComponent(curseur)}');
      _reels = [...?_reels, for (final x in (r.json['data'] as List? ?? []).cast<Map>()) _reelDe(x.cast<String, dynamic>())];
      _curseurReels = (r.json['meta'] as Map?)?['next_cursor'] as String?;
      _finReels = _curseurReels == null;
      notifyListeners();
    } catch (_) {
      _curseurReels = curseur;
    }
  }

  /// Les reels autour de la position (Pres de moi), du plus proche au plus loin.
  Future<List<Reel>?> reelsPresDeMoi() async {
    final p = _position;
    if (p == null) return null;
    try {
      final r = await Api.instance.get('reels?latitude=${p.latitude}&longitude=${p.longitude}&rayon=150');
      final liste = [for (final x in (r.json['data'] as List? ?? []).cast<Map>()) _reelDe(x.cast<String, dynamic>())];
      double d(Reel x) => x.latitude == null ? 1e9 : _distanceKm(p.latitude, p.longitude, x.latitude!, x.longitude!);
      return liste..sort((a, b) => d(a).compareTo(d(b)));
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ un lieu, une publication

  final _enCours = <String, Future<void>>{};

  /// Un lieu que l on ouvre par son lien sans l avoir vu passer (une notification).
  Future<Lieu?> chargerLieu(String id) async {
    if (_connus.containsKey(id)) return lieu(id);
    try {
      final r = await Api.instance.get('lieux/${Uri.encodeComponent(id)}');
      final l = _lieuDe((r.json['data'] as Map).cast<String, dynamic>(), avecVide: true);
      notifyListeners();
      return l;
    } catch (_) {
      return null;
    }
  }

  /// Toutes les publications d un lieu (les 20 plus recentes, puis la suite).
  Future<void> chargerContenus(String id) => _enCours[id] ??= _chargerContenus(id).whenComplete(() {
    _enCours.remove(id);
  });

  Future<void> _chargerContenus(String id) async {
    try {
      final liste = <Publication>[];
      String? curseur;
      // Un lieu a rarement plus de quelques centaines de publications : 5 pages au plus d un coup.
      for (var page = 0; page < 5; page++) {
        final r = await Api.instance.get('lieux/${Uri.encodeComponent(id)}/contenus${curseur == null ? '' : '?curseur=${Uri.encodeQueryComponent(curseur)}'}');
        liste.addAll([for (final c in (r.json['data'] as List? ?? []).cast<Map>()) _publicationDe(c.cast<String, dynamic>())]);
        curseur = (r.json['meta'] as Map?)?['next_cursor'] as String?;
        if (curseur == null) break;
      }
      _publications[id] = liste;
      _completes.add(id);
      notifyListeners();
    } catch (_) {
      // Hors ligne : la pile deja recue reste.
    }
  }

  /// Une publication ouverte par son identifiant (un lien, un createur, une notification).
  /// Faire connaitre une publication (son lieu surtout) sans attendre : ma copie gardee sur le
  /// telephone se retire de l accueil des que sa pile est la. Une fois par demi-minute au plus.
  void connaitrePublication(String id) {
    if (_parId[id]?.lieu != null) return;
    final avant = _demandees[id];
    if (avant != null && DateTime.now().difference(avant) < const Duration(seconds: 30)) return;
    _demandees[id] = DateTime.now();
    chargerPublication(id);
  }

  final _demandees = <String, DateTime>{};

  /// Une publication connue sans son lieu (venue d une liste qui ne le dit pas, comme mon profil)
  /// est redemandee : sinon sa page la croyait « Sans lieu ».
  Future<Publication?> chargerPublication(String id) async {
    final connue = _parId[id];
    if (connue != null && connue.lieu != null) return connue;
    try {
      final r = await Api.instance.get('contenus/${Uri.encodeComponent(id)}');
      final j = (r.json['data'] as Map).cast<String, dynamic>();
      final p = _publicationDe(j);
      final idLieu = p.lieu;
      // Une publication de lifestyle ne rejoint pas les photos de son lieu.
      if (idLieu != null && !p.duLifestyle) {
        final liste = _publications[idLieu] ??= [];
        if (!liste.any((x) => x.id == p.id)) _publications[idLieu] = [...liste, p];
      }
      notifyListeners();
      return p;
    } catch (_) {
      return connue;
    }
  }

  /// Mon titre et ma legende retouches (dans l heure qui suit la mise en ligne) : la publication
  /// changee remplace l ancienne partout ou elle s affiche. Leve ErreurApi (son message, par
  /// exemple « ne se modifie plus apres 1 h ») ou ApiInjoignable.
  Future<Publication> modifierPublication(String id, {required String titre, required String legende}) async {
    // Le nouveau texte s affiche tout de suite ; l ancien revient si le serveur refuse.
    _retouches[id] = (titre: titre, legende: legende);
    notifyListeners();
    try {
      final r = await Api.instance.patch('contenus/${Uri.encodeComponent(id)}', {'titre': titre.isEmpty ? null : titre, 'legende': legende.isEmpty ? null : legende});
      final p = _publicationDe((r.json['data'] as Map).cast<String, dynamic>());
      _publications.updateAll((_, liste) => [for (final x in liste) x.id == id ? p : x]);
      return p;
    } finally {
      _retouches.remove(id);
      notifyListeners();
    }
  }

  /// Le titre et la legende que je viens de retoucher, le temps que le serveur les prenne.
  final _retouches = <String, ({String titre, String legende})>{};

  ({String titre, String legende})? retouche(String? id) => id == null ? null : _retouches[id];

  /// Une publication sans lieu sur le serveur : un lieu a elle seule, pour ouvrir sa page.
  Lieu lieuSeul(Publication p) {
    final id = 'p:${p.id}';
    _completes.add(id);
    _publications[id] = [p];
    return _connus[id] ??= Lieu(
      id: id,
      nom: p.lieuNom ?? t('Sans lieu'),
      region: '',
      photos: [p.photo],
      nombre: 1,
      ratio: 0.75,
      type: '',
      latitude: p.latitude ?? 0,
      longitude: p.longitude ?? 0,
      situe: p.latitude != null && p.longitude != null,
    );
  }

  // ------------------------------------------------------------ chercher un lieu en publiant

  /// Les lieux de Discover pour ce texte, puis ceux de Google (pres de la position donnee).
  Future<({List<Lieu> lieux, List<({String id, String nom, String adresse})> google})?> suggestionsLieu(String texte, {double? latitude, double? longitude}) async {
    final q = texte.trim();
    if (q.length < 2) return null;
    try {
      final pres = latitude == null || longitude == null ? '' : '&latitude=$latitude&longitude=$longitude';
      final r = await Api.instance.get('lieux/suggestions?q=${Uri.encodeQueryComponent(q)}$pres');
      return (
        lieux: [for (final l in (r.json['lieux'] as List? ?? []).cast<Map>()) ?_lieuDe(l.cast<String, dynamic>(), avecVide: true)],
        google: [for (final g in (r.json['google'] as List? ?? []).cast<Map>()) (id: g['id'] as String? ?? '', nom: g['nom'] as String? ?? '', adresse: g['adresse'] as String? ?? '')],
      );
    } catch (_) {
      return null;
    }
  }

  /// Les telephones deja sur Discover dont le nom ressemble a ce texte (les plus utilises d abord).
  Future<List<String>> modelesTelephone(String texte) async {
    try {
      final r = await Api.instance.get('modeles-telephone?q=${Uri.encodeQueryComponent(texte.trim())}');
      return [for (final m in (r.json['data'] as List? ?? []).cast<Map>()) ?(m['complet'] as String?)];
    } catch (_) {
      return const [];
    }
  }

  /// Ou est un lieu de Google, pour y aller sur la carte (rien n est cree sur Discover).
  Future<({String nom, double latitude, double longitude})?> positionGoogle(String id) async {
    try {
      final r = await Api.instance.get('lieux/google/${Uri.encodeComponent(id)}');
      final d = (r.json['data'] as Map).cast<String, dynamic>();
      return (nom: d['nom'] as String? ?? '', latitude: (d['latitude'] as num).toDouble(), longitude: (d['longitude'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  /// Le lieu de Discover d un lieu choisi chez Google (cree au besoin, avec sa position).
  Future<Lieu?> lieuGoogle(String id) async {
    try {
      final r = await Api.instance.post('lieux/google', {'id': id});
      return _lieuDe((r.json['data'] as Map).cast<String, dynamic>(), avecVide: true);
    } catch (_) {
      return null;
    }
  }

  /// Les lieux d une zone de la carte (GET carte), 300 au plus, ceux qui n ont que des reels
  /// compris ; nul hors ligne.
  Future<List<Lieu>?> lieuxDeLaZone({required double nord, required double sud, required double est, required double ouest, List<String> types = const []}) async {
    String n(double v) => v.toStringAsFixed(5);
    final filtre = types.isEmpty ? '' : '&types=${Uri.encodeQueryComponent(types.join(','))}';
    try {
      final r = await Api.instance.get('carte?nord=${n(nord)}&sud=${n(sud)}&est=${n(est)}&ouest=${n(ouest)}$filtre');
      final lieux = [for (final l in (r.json['data'] as List? ?? []).cast<Map>()) ?_lieuDe(l.cast<String, dynamic>(), avecVide: true)];
      return [for (final l in lieux) _position == null || !l.situe ? l : l.aDistance(_km(l))];
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ chercher, un createur

  /// La recherche libre : des lieux, des createurs et des publications (le serveur ignore accents et majuscules).
  Future<({List<Lieu> lieux, List<Createur> createurs, List<Publication> publications})?> chercher(String texte) async {
    final q = texte.trim();
    if (q.isEmpty) return null;
    try {
      final r = await Api.instance.get('recherche?q=${Uri.encodeQueryComponent(q)}');
      final lieux = [for (final l in (r.json['lieux'] as List? ?? []).cast<Map>()) ?_lieuDe(l.cast<String, dynamic>())];
      final createurs = [
        for (final c in (r.json['createurs'] as List? ?? []).cast<Map>())
          Createur(
            pseudo: c['nom_utilisateur'] as String? ?? '',
            nom: (c['nom_affiche'] as String?) ?? (c['nom_utilisateur'] as String? ?? ''),
            bio: '',
            ville: '',
            abonnes: 0,
            avatar: c['avatar'] as String?,
            nombre: (c['nombre_contenus'] as num?)?.toInt(),
          ),
      ];
      final publications = [for (final c in (r.json['contenus'] as List? ?? []).cast<Map>()) _publicationDe(c.cast<String, dynamic>())];
      notifyListeners();
      return (lieux: [for (final l in lieux) _position == null || !l.situe ? l : l.aDistance(_km(l))], createurs: createurs, publications: publications);
    } catch (_) {
      return null;
    }
  }

  Createur? createurConnu(String pseudo) => _createurs[pseudo.replaceFirst('@', '')];

  /// Le profil d un createur et ses publications.
  Future<Createur?> chargerCreateur(String pseudo) async {
    final p = pseudo.replaceFirst('@', '');
    try {
      final r = await Api.instance.get('utilisateurs/${Uri.encodeComponent(p)}');
      final j = (r.json['data'] as Map).cast<String, dynamic>();
      final rc = await Api.instance.get('utilisateurs/${Uri.encodeComponent(p)}/contenus');
      final publications = [for (final c in (rc.json['data'] as List? ?? []).cast<Map>()) _publicationDe(c.cast<String, dynamic>())];
      final c = Createur(
        pseudo: p,
        nom: (j['nom_affiche'] as String?) ?? p,
        bio: (j['bio'] as String?) ?? '',
        ville: (j['ville'] as String?) ?? '',
        abonnes: ((j['compteurs'] as Map?)?['abonnes'] as num?)?.toInt() ?? 0,
        publications: publications,
        avatar: j['avatar'] as String?,
        nombre: ((j['compteurs'] as Map?)?['contenus'] as num?)?.toInt(),
        site: j['site'] as String?,
        lifestyle: ((j['compteurs'] as Map?)?['lifestyle'] as num?)?.toInt() ?? 0,
      );
      _createurs[p] = c;
      notifyListeners();
      return c;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ du JSON aux modeles

  static String? _url(Map<String, dynamic> j, List<String> tailles) {
    final images = (j['images'] as Map?) ?? const {};
    for (final t in tailles) {
      final u = (images[t] as Map?)?['url'] as String?;
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  /// Un lieu et sa pile ; nul s il n a aucune photo a montrer (que des reels).
  Lieu? _lieuDe(Map<String, dynamic> j, {bool avecVide = false}) {
    final photos = [for (final p in (j['photos'] as List? ?? []).cast<Map>()) _publicationDe(p.cast<String, dynamic>(), lieuId: j['id'] as String?)];
    final id = j['id'] as String;
    // Une reponse sans pile (la recherche d un lieu en publiant) n efface pas celle deja connue.
    final deja = _connus[id];
    if (!j.containsKey('photos') && deja != null && deja.photos.isNotEmpty) return deja;
    final ratio = photos.isEmpty ? 0.75 : (ratioDe(photos.first.photo)).clamp(0.75, 1.0);
    final l = Lieu(
      id: id,
      nom: j['nom'] as String? ?? '',
      region: j['region'] as String? ?? '',
      photos: [for (final p in photos) p.photo],
      // Les publications de sa pile : les reels filmes dans Discover sont dans les Reels.
      nombre: math.max(0, ((j['nombre_contenus'] as num?)?.toInt() ?? photos.length) - ((j['nombre_reels'] as num?)?.toInt() ?? 0)),
      ratio: ratio.toDouble(),
      type: j['type'] as String? ?? '',
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
      distanceKm: (j['distance_km'] as num?)?.round(),
      situe: j['situe'] != false && j['latitude'] != null,
      pays: j['pays'] as String?,
      nombreReels: (j['nombre_reels'] as num?)?.toInt(),
      nombreVerifiees: (j['nombre_verifiees'] as num?)?.toInt(),
    );
    _connus[id] = l;
    // La pile sert de debut de liste, en attendant toutes les publications du lieu.
    // Celles deja connues hors de la pile (ouvertes par une notification, une recherche) restent.
    if (!_completes.contains(id) && photos.isNotEmpty) {
      final ids = {for (final p in photos) p.id};
      _publications[id] = [...photos, ...?_publications[id]?.where((p) => p.id == null || !ids.contains(p.id))];
    }
    if (photos.isEmpty && !avecVide) return null;
    return l;
  }

  Publication _publicationDe(Map<String, dynamic> j, {String? lieuId}) {
    final reel = j['type'] == 'reel';
    // Les tailles portent le nom du grand cote : « 480 » d une photo en hauteur ne fait que 219 px
    // de large, floue sur une carte de 500 px. Les cartes prennent « 1080 », la page « 2160 ».
    final petite = _url(j, reel ? ['affiche', '480', '1080'] : ['1080', '2160', '480']) ?? '';
    final grande = _url(j, reel ? ['affiche', '1080'] : ['2160', '1080', '480']) ?? petite;
    final ratio = (j['ratio'] as num?)?.toDouble();
    if (ratio != null && ratio > 0) {
      ratiosFichiers[petite] = ratio;
      ratiosFichiers[grande] = ratio;
    }
    final auteur = (j['auteur'] as Map?)?.cast<String, dynamic>();
    final lieu = (j['lieu'] as Map?)?.cast<String, dynamic>();
    final capture = (j['capture'] as Map?)?.cast<String, dynamic>();
    final compteurs = (j['compteurs'] as Map?) ?? const {};
    // Une version plus courte de la meme publication (sans auteur ni fiche de prise) ne
    // fait pas oublier ce qui est deja connu : jamais un auteur ou un telephone invente.
    final connue = _parId[j['id']];
    final p = Publication(
      id: j['id'] as String?,
      photo: petite,
      grande: grande,
      video: _url(j, ['video']),
      auteur: auteur?['nom_utilisateur'] != null ? '@${auteur!['nom_utilisateur']}' : (connue?.auteur ?? ''),
      nomAuteur: (auteur?['nom_affiche'] as String?) ?? connue?.nomAuteur,
      appareil: (capture?['telephone'] as String?) ?? (capture == null ? connue?.appareil : null) ?? t('Téléphone non indiqué'),
      verifiee: j['badge'] == 'verifiee',
      dureeReel: reel ? ((j['duree'] as num?)?.toInt() ?? 1) : null,
      filmeeDansDiscover: reel && (capture == null ? connue?.filmeeDansDiscover == true : capture['source'] == 'appareil'),
      duLifestyle: j['portee'] == 'lifestyle' || (j['portee'] == null && connue?.duLifestyle == true),
      lieu: (lieu?['id'] as String?) ?? lieuId,
      // Le nom donne sans position (« Chez ma grand-mere ») passe avant celui de la pile « Sans lieu ».
      lieuNom: (j['nom_lieu'] as String?) ?? lieu?['nom'] as String?,
      titre: j['titre'] as String?,
      legende: j['legende'] as String?,
      priseLe: capture == null ? connue?.priseLe : DateTime.tryParse((capture['prise_le'] as String?) ?? ''),
      latitude: (capture?['latitude'] as num?)?.toDouble(),
      longitude: (capture?['longitude'] as num?)?.toDouble(),
      jaime: (compteurs['reactions'] as num?)?.toInt() ?? 0,
      commentaires: (compteurs['commentaires'] as num?)?.toInt() ?? 0,
      vues: (compteurs['vues'] as num?)?.toInt() ?? 0,
      maReaction: (j['moi'] as Map?)?['reaction'] as String?,
      enregistreParMoi: (j['moi'] as Map?)?['enregistre'] == true,
      avatarAuteur: (auteur?['avatar'] as String?) ?? connue?.avatarAuteur,
      tresGrande: reel ? null : _url(j, ['3840']),
      videoHd: _url(j, ['video-1080']),
      videoApercu: _url(j, ['video-640']),
      modifiableJusquAu: DateTime.tryParse(j['modifiable_jusqu_au'] as String? ?? '')?.toLocal(),
      tailles: {
        for (final e in ((j['images'] as Map?) ?? const {}).entries)
          if (e.value is Map && (e.value as Map)['largeur'] is num && (e.value as Map)['hauteur'] is num)
            e.key as String: (largeur: ((e.value as Map)['largeur'] as num).toInt(), hauteur: ((e.value as Map)['hauteur'] as num).toInt()),
      },
      origines: capture == null
          ? (connue?.origines ?? const {})
          : {
              for (final e in ((capture['origines'] as Map?) ?? const {}).entries)
                if (e.value is String) e.key as String: e.value as String,
            },
    );
    final id = p.id;
    if (id != null) _parId[id] = p;
    if (p.video != null) {
      for (final affiche in [p.photo, ?p.grande]) {
        videosDesAffiches[affiche] = p.videoApercu ?? p.video!;
      }
    }
    // Le lieu d une publication est connu, meme s il n est pas encore passe a l accueil.
    if (lieu != null && lieu['id'] is String && !_connus.containsKey(lieu['id'])) {
      _connus[lieu['id'] as String] = Lieu(
        id: lieu['id'] as String,
        nom: lieu['nom'] as String? ?? '',
        region: lieu['region'] as String? ?? '',
        photos: [petite],
        nombre: 1,
        ratio: 0.75,
        type: '',
        latitude: (lieu['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (lieu['longitude'] as num?)?.toDouble() ?? 0,
        situe: lieu['situe'] != false && lieu['latitude'] != null,
      );
    }
    return p;
  }

  Reel _reelDe(Map<String, dynamic> j) {
    final p = _publicationDe(j);
    final compteurs = (j['compteurs'] as Map?) ?? const {};
    return Reel(
      id: p.id,
      photo: p.grande ?? p.photo,
      video: p.video,
      pseudo: p.auteur.replaceFirst('@', ''),
      nom: p.nomAuteur ?? p.auteur.replaceFirst('@', ''),
      legende: p.legende ?? '',
      appareil: p.appareil,
      lieu: p.lieu ?? '',
      lieuNom: p.lieuNom,
      latitude: _connus[p.lieu]?.latitude ?? p.latitude,
      longitude: _connus[p.lieu]?.longitude ?? p.longitude,
      duree: p.dureeReel ?? 1,
      jaime: p.jaime,
      commentaires: p.commentaires,
      enregistres: (compteurs['enregistrements'] as num?)?.toInt() ?? 0,
      partages: (compteurs['partages'] as num?)?.toInt() ?? 0,
      vues: p.vues,
      son: (j['son'] as String?) ?? "Son d'origine",
      maReaction: p.maReaction,
      verifiee: p.verifiee,
      avatar: p.avatarAuteur,
      videoHd: p.videoHd,
      musiqueId: (j['musique'] as Map?)?['id'] as String?,
      musiqueActive: (j['musique'] as Map?)?['actif'] != false,
    );
  }

  /// Un reel par son identifiant, du serveur (un reel ouvert d un profil, d un lien, d une
  /// notification) ; nul s il n est plus la.
  Future<Reel?> chargerReel(String id) async {
    try {
      final r = await Api.instance.get('contenus/${Uri.encodeComponent(id)}');
      return _reelDe((r.json['data'] as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// Des reels du serveur (la page d un son), en modeles.
  List<Reel> reelsDepuis(List<Map<String, dynamic>> json) => [for (final j in json) _reelDe(j)];

  /// Des publications du serveur (une collection, mon profil), en modeles.
  List<Publication> publicationsDepuis(List<Map<String, dynamic>> json) => [for (final j in json) _publicationDe(j)];

  /// Mes publications en ligne (E18), les plus recentes d abord ; nul hors ligne ou sans compte.
  Future<List<Publication>?> mesContenus() async {
    if (Api.instance.jeton == null) return null;
    try {
      final r = await Api.instance.get('moi/contenus');
      return [
        for (final c in (r.json['data'] as List? ?? []).cast<Map>())
          if (c['statut'] == 'publie') _publicationDe(c.cast<String, dynamic>()),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Les reels des createurs que je suis (Abonnements) ; nul hors ligne ou sans compte.
  Future<List<Reel>?> reelsAbonnements() async {
    if (Api.instance.jeton == null) return null;
    try {
      final r = await Api.instance.get('reels?abonnements=1');
      return [for (final x in (r.json['data'] as List? ?? []).cast<Map>()) _reelDe(x.cast<String, dynamic>())];
    } catch (_) {
      return null;
    }
  }

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0088;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a.toDouble())));
  }

  /// Un autre compte sur ce telephone : ses lieux masques et ce qui etait a lui (ses « j aime »,
  /// ses enregistrements, dans les publications gardees) ne passent pas au suivant ; l accueil
  /// se redemande.
  void oublierLeCompte() {
    masques.clear();
    SharedPreferences.getInstance().then((p) => p.remove(_cleMasques)).ignore();
    // La copie de l accueil gardee sur le telephone porte les « j aime » du compte qui l a chargee.
    _fichier().then((f) => f.delete()).then((_) {}, onError: (_) {});
    // L accueil reste affiche pendant qu il se recharge (le vider laissait un logo qui tourne) ;
    // seul ce qui vient du compte (mes reactions sur les publications) est oublie.
    _generation++;
    _publications.clear();
    _completes.clear();
    _parId.clear();
    _createurs.clear();
    horsLigne = false;
    notifyListeners();
    rafraichir().ignore();
  }

  /// Pour les tests : on repart de la demonstration.
  @visibleForTesting
  void oublier() {
    _lieux = null;
    _reels = null;
    _connus.clear();
    _publications.clear();
    _completes.clear();
    _parId.clear();
    _createurs.clear();
    _position = null;
    _avecDistances = null;
    horsLigne = false;
    notifyListeners();
  }
}

/// Range les photos de la vitrine en [colonnes] colonnes (colonne apres colonne) pour que
/// deux voisines ne se ressemblent pas : ni la meme photo, ni le meme lieu, cote a cote, l une
/// sous l autre ou en diagonale. Les colonnes de l entree glissent chacune a son rythme et
/// reprennent du debut en bas : toute la colonne d a cote finit par passer a cote, et le bas
/// d une colonne touche son haut. Chaque case prend la photo qui gene le moins ses voisines ;
/// a egalite, les lieux viennent a tour de role.
List<String> disposerVitrine(List<({String photo, String lieu})> candidats, int n, int colonnes) {
  if (candidats.isEmpty || n <= 0) return List.filled(math.max(n, 0), '');
  final lignes = (n / colonnes).ceil();
  final parLieu = <String, List<({String photo, String lieu})>>{};
  for (final c in candidats) {
    (parLieu[c.lieu] ??= []).add(c);
  }
  final ordre = [
    for (var i = 0; parLieu.values.any((l) => i < l.length); i++)
      for (final l in parLieu.values)
        if (i < l.length) l[i],
  ].take(80).toList();
  final grille = List<({String photo, String lieu})?>.filled(n, null);
  ({String photo, String lieu})? a(int c, int l) => c < 0 || c >= colonnes || l < 0 || l >= lignes || c * lignes + l >= n ? null : grille[c * lignes + l];
  final emplois = <String, int>{};
  for (var l = 0; l < lignes; l++) {
    for (var c = 0; c < colonnes; c++) {
      final i = c * lignes + l;
      if (i >= n) continue;
      var meilleur = ordre.first;
      var moindre = -1;
      for (final x in ordre) {
        var cout = (emplois[x.photo] ?? 0) * 50;
        for (var ll = 0; ll < lignes; ll++) {
          // Dans sa colonne : celle du dessus, et la premiere pour la derniere (la colonne reboucle).
          final m = a(c, ll);
          if (m != null) {
            final contre = ll == l - 1 || (l == lignes - 1 && ll == 0 && lignes > 2);
            if (m.photo == x.photo) {
              cout += contre ? 1000 : 500;
            } else if (m.lieu == x.lieu) {
              cout += contre ? 100 : 10;
            }
          }
          // Les colonnes d a cote : tout y passe un jour a cote, la ligne voisine d abord.
          for (final cc in [c - 1, c + 1]) {
            final v = a(cc, ll);
            if (v == null) continue;
            final proche = (ll - l).abs() <= 1;
            if (v.photo == x.photo) {
              cout += proche ? 1000 : 300;
            } else if (v.lieu == x.lieu) {
              cout += proche ? 60 : 20;
            }
          }
        }
        if (moindre < 0 || cout < moindre) {
          moindre = cout;
          meilleur = x;
        }
      }
      grille[i] = meilleur;
      emplois[meilleur.photo] = (emplois[meilleur.photo] ?? 0) + 1;
    }
  }
  return [for (final g in grille) g?.photo ?? ''];
}
