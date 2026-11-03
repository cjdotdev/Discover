// Les envois en cours (E16, E26). Une publication part en deux temps vers
// l API (lot 3, ARCHITECTURE.md 6.3) : l apercu WebP d abord (il suffit a
// publier une photo), puis l original. Chaque fichier part par morceaux ; si
// le reseau tombe, l envoi se met en pause et reprend tout seul la ou le
// serveur s est arrete (HEAD), meme apres avoir ferme l application.
// Deconnecte, il attend la connexion, puis repart seul.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/etiquettes.dart';
import '../outils/reseau.dart';
import '../outils/type_media.dart';
import '../outils/api.dart';
import '../outils/appareil.dart';
import '../outils/langue.dart';
import 'catalogue.dart';
import 'mes_publications.dart';

enum EtatEnvoi { encours, pause, verification, publie, refuse }

/// Ce qu il faut envoyer, et ce que l on sait de la prise.
class AEnvoyer {
  AEnvoyer({
    required this.reel,
    required this.original,
    required this.image,
    this.duree,
    this.legende = '',
    this.titre,
    this.lieuId,
    this.lieuNom,
    double? lieuLatitude,
    double? lieuLongitude,
    this.nomLieu,
    this.ville = '',
    this.region = '',
    this.pays = '',
    this.paysCode = '',
    double? latitude,
    double? longitude,
    this.priseLe,
    this.modele,
    this.priseAvecDiscover = false,
    this.modeleDeclare = false,
    this.dateDeclaree = false,
    this.musique,
    this.etiquettes,
    this.portee,
  }) : lieuLatitude = _fini(lieuLatitude),
       lieuLongitude = _fini(lieuLongitude),
       latitude = _fini(latitude),
       longitude = _fini(longitude);

  // Une position abimee (un GPS sans signal ecrit 0/0 dans la photo, soit NaN) ne part pas :
  // elle ne s ecrit pas en JSON, et l envoi restait bloque a 0 %.
  static double? _fini(double? x) => x != null && x.isFinite ? x : null;

  /// Ce que le telephone voit sur l image (Google ML Kit), lu une fois avant la creation.
  List<Map<String, Object?>>? etiquettes;

  /// « lifestyle » : pour mon lifestyle (hors de l accueil) ; nul : Discover.
  final String? portee;

  final bool reel;

  /// La musique du catalogue choisie au montage : son identifiant, son extrait, les deux volumes
  /// (le serveur la mele a la video).
  final Map<String, Object?>? musique;

  /// Le fichier tel quel : la photo, ou la video du reel.
  final String original;

  /// L image d ou tirer l apercu : la photo, ou la couverture du reel.
  final String image;
  final int? duree;
  final String legende;
  final String? titre;
  final String? lieuId;
  final String? lieuNom;

  /// Le point pose sur la carte (pas la position de la prise).
  final double? lieuLatitude, lieuLongitude;

  /// Un nom seul, sans position ; vide : « Sans lieu ». Nul : le lieu vient d ailleurs.
  final String? nomLieu;
  final String ville, region, pays, paysCode;
  final double? latitude, longitude;
  final DateTime? priseLe;

  /// « Tecno Camon 50 Pro » : la marque est le premier mot.
  final String? modele;
  final bool priseAvecDiscover;
  final bool modeleDeclare, dateDeclaree;

  // D ou vient chaque information : de l appareil photo a l instant, du fichier, ou du membre.
  String _origine(bool declaree) => declaree ? 'declaree' : (priseAvecDiscover ? 'appareil' : 'exif');

  Map<String, Object?> corps(Map<String, Map<String, Object>> fichiers) {
    final m = modele?.trim() ?? '';
    final espace = m.indexOf(' ');
    return {
      'type': reel ? 'reel' : 'photo',
      if (portee != null) 'portee': portee,
      'legende': legende,
      'titre': titre,
      if (reel) 'duree': (duree ?? 1).clamp(1, 60),
      if (reel && musique != null) 'musique': musique,
      if (etiquettes != null && etiquettes!.isNotEmpty) 'etiquettes': etiquettes,
      if (lieuId != null) 'lieu': lieuId,
      if (lieuNom != null && lieuNom!.isNotEmpty) 'lieu_nom': lieuNom,
      if (lieuLatitude != null && lieuLongitude != null) ...{'lieu_latitude': lieuLatitude, 'lieu_longitude': lieuLongitude},
      if (nomLieu != null) 'nom_lieu': nomLieu,
      if (ville.isNotEmpty) 'ville': ville,
      if (region.isNotEmpty) 'region': region,
      if (pays.isNotEmpty) 'pays': pays,
      if (paysCode.length == 2) 'pays_code': paysCode,
      'capture': {
        'source': priseAvecDiscover ? 'appareil' : (modeleDeclare || dateDeclaree ? 'declaree' : 'fichier'),
        if (espace > 0) 'marque': m.substring(0, espace),
        if (espace > 0) 'modele': m.substring(espace + 1),
        if (priseLe != null) 'prise_le': priseLe!.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'origines': {'modele': _origine(modeleDeclare), 'date': _origine(dateDeclaree), 'position': latitude == null ? 'declaree' : _origine(false)},
      },
      'fichiers': fichiers,
    };
  }

  Map<String, Object?> versJson() => {
    'reel': reel,
    'original': original,
    'image': image,
    'duree': duree,
    'legende': legende,
    'titre': titre,
    'lieuId': lieuId,
    'lieuNom': lieuNom,
    'lieuLatitude': lieuLatitude,
    'lieuLongitude': lieuLongitude,
    'nomLieu': nomLieu,
    'ville': ville,
    'region': region,
    'pays': pays,
    'paysCode': paysCode,
    'latitude': latitude,
    'longitude': longitude,
    'priseLe': priseLe?.millisecondsSinceEpoch,
    'modele': modele,
    'priseAvecDiscover': priseAvecDiscover,
    'modeleDeclare': modeleDeclare,
    'dateDeclaree': dateDeclaree,
    'musique': musique,
    'etiquettes': etiquettes,
    'portee': portee,
  };

  static AEnvoyer depuisJson(Map<String, Object?> j) => AEnvoyer(
    reel: j['reel'] == true,
    original: j['original'] as String,
    image: j['image'] as String,
    duree: (j['duree'] as num?)?.toInt(),
    legende: j['legende'] as String? ?? '',
    titre: j['titre'] as String?,
    lieuId: j['lieuId'] as String?,
    lieuNom: j['lieuNom'] as String?,
    lieuLatitude: (j['lieuLatitude'] as num?)?.toDouble(),
    lieuLongitude: (j['lieuLongitude'] as num?)?.toDouble(),
    nomLieu: j['nomLieu'] as String?,
    ville: j['ville'] as String? ?? '',
    region: j['region'] as String? ?? '',
    pays: j['pays'] as String? ?? '',
    paysCode: j['paysCode'] as String? ?? '',
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    priseLe: j['priseLe'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['priseLe'] as num).toInt()),
    modele: j['modele'] as String?,
    priseAvecDiscover: j['priseAvecDiscover'] == true,
    modeleDeclare: j['modeleDeclare'] == true,
    dateDeclaree: j['dateDeclaree'] == true,
    musique: (j['musique'] as Map?)?.cast<String, Object?>(),
    etiquettes: j['etiquettes'] == null ? null : [for (final e in j['etiquettes'] as List) (e as Map).cast<String, Object?>()],
    portee: j['portee'] as String?,
  );
}

class Envoi {
  Envoi({required this.titre, required this.photo, required this.poidsMo, this.etat = EtatEnvoi.encours, this.avance = 0, this.detail, this.source, this.locale});

  final String titre;
  final String photo;
  final double poidsMo;
  EtatEnvoi etat;

  /// De 0 a 1.
  double avance;
  String? detail;

  /// Un vrai envoi vers l API (nul en demonstration).
  final AEnvoyer? source;

  /// La photo de la publication gardee sur le telephone (mes publications).
  final String? locale;

  /// Le contenu cree sur le serveur, et ses envois : role -> identifiant, taille, recu.
  String? contenu;
  final ids = <String, String>{};
  final tailles = <String, int>{};
  final recus = <String, int>{};
  final termines = <String>{};

  /// L apercu fabrique sur le telephone.
  String? apercu;

  /// Le fichier allege sur le telephone, qui part a la place de l original.
  String? optimise;

  /// En verification, ce que le serveur attend : 'a_completer' (de l auteur) ou
  /// 'file_humaine' (de l equipe). Nul : l analyse tourne encore.
  String? attente;

  /// A completer : ce qui manque (telephone, date).
  final manque = <String>[];

  /// Le motif du refus donne par le serveur (nul : refuse sur le telephone).
  String? motif;

  Map<String, Object?> versJson() => {
    'titre': titre,
    'photo': photo,
    'poidsMo': poidsMo,
    'etat': etat.name,
    'avance': avance,
    'detail': detail,
    'source': source?.versJson(),
    'locale': locale,
    'contenu': contenu,
    'ids': ids,
    'tailles': tailles,
    'recus': recus,
    'termines': termines.toList(),
    'apercu': apercu,
    'optimise': optimise,
    'attente': attente,
    'manque': manque,
    'motif': motif,
  };

  static Envoi depuisJson(Map<String, Object?> j) {
    final e = Envoi(
      titre: j['titre'] as String? ?? '',
      photo: j['photo'] as String? ?? '',
      poidsMo: (j['poidsMo'] as num?)?.toDouble() ?? 1,
      etat: EtatEnvoi.values.byName(j['etat'] as String? ?? 'pause'),
      avance: (j['avance'] as num?)?.toDouble() ?? 0,
      detail: j['detail'] as String?,
      source: j['source'] == null ? null : AEnvoyer.depuisJson((j['source'] as Map).cast<String, Object?>()),
      locale: j['locale'] as String?,
    )..contenu = j['contenu'] as String?;
    e.ids.addAll(((j['ids'] as Map?) ?? const {}).cast<String, String>());
    e.tailles.addAll({for (final x in ((j['tailles'] as Map?) ?? const {}).entries) x.key as String: (x.value as num).toInt()});
    e.recus.addAll({for (final x in ((j['recus'] as Map?) ?? const {}).entries) x.key as String: (x.value as num).toInt()});
    e.termines.addAll(((j['termines'] as List?) ?? const []).cast<String>());
    e
      ..apercu = j['apercu'] as String?
      ..optimise = j['optimise'] as String?
      ..attente = j['attente'] as String?
      ..motif = j['motif'] as String?;
    e.manque.addAll(((j['manque'] as List?) ?? const []).cast<String>());
    return e;
  }
}

class Envois extends ChangeNotifier {
  Envois._();
  static final instance = Envois._();

  static const _cle = 'envois';

  /// Les morceaux : 1 Mo (le serveur accepte jusqu a 4 Mo).
  static const morceau = 1024 * 1024;

  final liste = <Envoi>[];

  Timer? _reprise;
  bool _occupe = false;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _suivreEnFond();
  }

  // La notification des envois, qui garde Discover en vie quand on le quitte (comme Instagram) :
  // montree tant qu un envoi avance, retiree des que tout est parti (Reglages : desactivable).
  String? _dernierEnFond;

  void _suivreEnFond() {
    final enCours = liste.where((e) => e.source != null && e.etat == EtatEnvoi.encours).toList();
    if (enCours.isEmpty || !Reseau.instance.envoisEnFond) {
      if (_dernierEnFond != null) {
        _dernierEnFond = null;
        unawaited(Appareil.envoisFinis());
      }
      return;
    }
    final pct = (enCours.fold<double>(0, (a, e) => a + e.avance) / enCours.length * 100).round();
    final titre = tn(enCours.length, 'Envoi de votre publication', 'Envoi de {n} publications');
    final texte = enCours.first.detail ?? '$pct %';
    final cle = '$titre|$texte|$pct';
    if (cle == _dernierEnFond) return;
    _dernierEnFond = cle;
    unawaited(Appareil.envoisEnFond(titre: titre, texte: texte, avance: pct));
  }

  /// L envoi qui avance en ce moment (la pastille au-dessus des onglets).
  Envoi? get courant => liste.where((e) => e.etat == EtatEnvoi.encours).firstOrNull;

  /// Au demarrage : les envois laisses en route reprennent.
  Future<void> charger() async {
    if (Api.instance.jeton == null) return;
    try {
      final brut = (await SharedPreferences.getInstance()).getString(_cle);
      if (brut == null) return;
      liste
        ..clear()
        ..addAll([for (final j in jsonDecode(brut) as List) Envoi.depuisJson((j as Map).cast<String, Object?>())]);
      for (final e in liste) {
        if (e.etat == EtatEnvoi.pause && e.source != null) e.etat = EtatEnvoi.encours;
      }
      notifyListeners();
      _suivant();
      // Ceux qui attendaient une decision la redemandent : elle a pu tomber entre-temps.
      unawaited(actualiser());
    } catch (_) {}
  }

  Future<void> _garder() async {
    try {
      final reels = [
        for (final e in liste)
          if (e.source != null) e.versJson(),
      ];
      await (await SharedPreferences.getInstance()).setString(_cle, jsonEncode(reels));
    } catch (_) {}
  }

  void publier({required String titre, required String photo, required double poidsMo, AEnvoyer? source, String? locale}) {
    if (source == null) return;
    final e = Envoi(titre: titre, photo: photo, poidsMo: poidsMo, source: source, locale: locale);
    liste.insert(0, e);
    // Pas connecté (la session a expiré) : il attend la connexion, rien n'est perdu.
    if (Api.instance.jeton == null) {
      e
        ..etat = EtatEnvoi.pause
        ..detail = reconnecter;
    }
    notifyListeners();
    _garder();
    _suivant();
  }

  /// Après une connexion : les envois qui l'attendaient repartent (et ceux gardés sur le téléphone).
  Future<void> apresConnexion() async {
    if (liste.isEmpty) return charger();
    for (final e in liste) {
      if (e.etat == EtatEnvoi.pause && e.detail == reconnecter) {
        e
          ..etat = EtatEnvoi.encours
          ..detail = null;
      }
    }
    notifyListeners();
    _suivant();
  }

  void basculer(Envoi e) {
    e.etat = e.etat == EtatEnvoi.pause ? EtatEnvoi.encours : EtatEnvoi.pause;
    if (e.etat == EtatEnvoi.encours) e.detail = null;
    notifyListeners();
    _garder();
    _suivant();
  }

  /// Un autre compte sur ce telephone (deconnexion, session expiree) : les envois de l ancien
  /// partent de la liste. Celui en route s arrete au prochain morceau, et rien ne repart sous
  /// le nouveau compte.
  /// [garderEnCours] : ceux encore en route continuent (leur compte n est pas connu).
  void oublier({bool garderEnCours = false}) {
    final partent = [
      for (final e in liste)
        if (!garderEnCours || e.etat == EtatEnvoi.publie || e.etat == EtatEnvoi.refuse || e.etat == EtatEnvoi.verification) e,
    ];
    for (final e in partent) {
      e.etat = EtatEnvoi.pause;
      liste.remove(e);
    }
    notifyListeners();
    _garder();
  }

  void annuler(Envoi e) {
    liste.remove(e);
    notifyListeners();
    _garder();
    // Le brouillon et ses morceaux sur le serveur partent aussi.
    final c = e.contenu;
    if (c != null && e.etat != EtatEnvoi.publie) Api.instance.delete('contenus/$c').ignore();
  }

  // ---------------------------------------------------------------- l envoi reel

  /// En attente du Wi-Fi (« Envoyer en Wi-Fi seulement ») : la raison affichée.
  static String get attendWifi => t('en attente du Wi-Fi');

  /// La session a expire : l envoi attend la connexion.
  static String get reconnecter => t('reconnectez-vous pour continuer');

  bool _ecouteReseau = false;

  void _reseauChange() {
    if (Reseau.instance.envoisEnAttente) return;
    var repris = false;
    for (final x in liste) {
      if (x.etat == EtatEnvoi.pause && x.detail == attendWifi) {
        x.etat = EtatEnvoi.encours;
        repris = true;
      }
    }
    if (repris) {
      notifyListeners();
      _suivant();
    }
  }

  void _suivant() {
    if (_occupe) return;
    if (!_ecouteReseau) {
      _ecouteReseau = true;
      Reseau.instance.addListener(_reseauChange);
    }
    final e = liste.where((x) => x.source != null && x.etat == EtatEnvoi.encours).firstOrNull;
    if (e == null) return;
    if (Reseau.instance.envoisEnAttente) {
      e
        ..etat = EtatEnvoi.pause
        ..detail = attendWifi;
      notifyListeners();
      return;
    }
    _occupe = true;
    _envoyer(e).whenComplete(() {
      _occupe = false;
      _garder();
      notifyListeners();
      _suivant();
    });
  }

  Future<void> _envoyer(Envoi e) async {
    final s = e.source!;
    try {
      // 1. Le brouillon et ses deux envois, une seule fois.
      if (e.contenu == null) {
        // Ni une photo ni une video (un texte choisi dans la galerie) : refusee ici, avec la
        // raison, au lieu de rester en attente sur le telephone.
        if (await typeDeMedia(s.original) == null) {
          _refuser(e, t('Ce fichier n’est pas une photo ni une vidéo : Discover ne peut pas le publier.'));
          return;
        }
        e.detail = t('Préparation…');
        notifyListeners();
        final apercu = e.apercu ?? await Appareil.apercu(s.image) ?? s.image;
        e.apercu = apercu;
        // Ce qu on voit dessus, lu ici sur l apercu (rapide, hors connexion) : « arbre » la trouvera.
        s.etiquettes ??= await Etiquettes.instance.lire(apercu);
        // Le fichier allege ici (comme TikTok) : bien plus petit, il part bien plus vite.
        if (e.optimise == null || !File(e.optimise!).existsSync()) {
          e.detail = s.reel ? t('Optimisation de la vidéo…') : t('Optimisation de la photo…');
          notifyListeners();
          e.optimise = await Appareil.optimiser(s.original, video: s.reel);
          unawaited(_garder());
        }
        final fichiers = <String, Map<String, Object>>{};
        for (final (role, chemin) in [('apercu', apercu), ('original', e.optimise!)]) {
          final f = File(chemin);
          final empreinte = await Appareil.empreinte(chemin);
          if (!f.existsSync() || empreinte == null) throw const FormatException('fichier introuvable');
          fichiers[role] = {'taille': f.lengthSync(), 'type': _type(chemin, s.reel && role == 'original'), 'empreinte': empreinte};
        }
        // Oublie entre-temps (un autre compte) : il ne se publie pas sous ce compte-la.
        if (!liste.contains(e)) return;
        final r = await Api.instance.post('contenus', s.corps(fichiers));
        e.contenu = (r.json['contenu'] as Map)['id'] as String;
        final locale = e.locale;
        if (locale != null) unawaited(MesPublications.instance.lier(locale, e.contenu!));
        for (final x in (r.json['envois'] as Map).entries) {
          final v = (x.value as Map).cast<String, Object?>();
          e.ids[x.key as String] = v['id'] as String;
          e.tailles[x.key as String] = (v['taille'] as num).toInt();
          e.recus[x.key as String] = (v['decalage'] as num).toInt();
        }
        await _garder();
      }
      // 2. L apercu, puis l original, par morceaux.
      for (final (role, chemin) in [('apercu', e.apercu!), ('original', e.optimise ?? s.original)]) {
        if (e.termines.contains(role)) continue;
        if (!await _fichier(e, role, chemin)) return;
      }
      // Tout est arrive : les fichiers prepares ici (l apercu, la version allegee) ne servent plus.
      for (final prepare in {e.apercu, e.optimise}) {
        if (prepare != null && prepare != s.original && prepare != s.image && prepare.contains('${Platform.pathSeparator}envois${Platform.pathSeparator}')) {
          File(prepare).delete().then((_) {}, onError: (_) {});
        }
      }
      // 3. La decision du serveur.
      e
        ..etat = EtatEnvoi.verification
        ..avance = 1
        ..attente = null
        ..detail = enAnalyse;
      notifyListeners();
      _suivis.add(e);
      try {
        await _attendreDecision(e);
      } finally {
        _suivis.remove(e);
      }
    } on ApiInjoignable {
      _enPause(e, t('reprendra dès que le réseau revient'));
    } on ErreurApi catch (err) {
      if (err.code == 409 && e.contenu == null) {
        _refuser(e, err.message);
      } else if (err.code == 401) {
        _enPause(e, reconnecter);
      } else if (err.code == 429) {
        // Beaucoup de publications d un coup (le lot) : on attend, rien n est perdu.
        _enPause(e, t('reprendra dans un moment'), apres: const Duration(minutes: 2));
      } else if (err.code == 422 && err.erreurs.containsKey('fichier')) {
        // Abime en route : le serveur repart de zero, l envoi aussi.
        e.recus.updateAll((_, _) => 0);
        _enPause(e, err.pour('fichier'));
      } else {
        _refuser(e, err.message);
      }
    } on FormatException {
      _refuser(e, t('Le fichier n’est plus sur le téléphone.'));
    } on FileSystemException {
      _refuser(e, t('Le fichier n’est plus sur le téléphone.'));
    } catch (err, pile) {
      // Une erreur imprevue : l envoi se repose et retente dans 2 minutes, au lieu de repartir
      // aussitot en boucle, bloque a 0 %.
      debugPrint('Discover envoi : $err \n$pile');
      _enPause(e, t('reprendra dans un moment'), apres: const Duration(minutes: 2));
    }
  }

  // Un fichier, morceau apres morceau, a partir de ce que le serveur a deja.
  Future<bool> _fichier(Envoi e, String role, String chemin) async {
    final id = e.ids[role]!;
    final etat = await Api.instance.head('envois/$id');
    var decalage = int.tryParse(etat.entetes['upload-offset'] ?? '') ?? 0;
    final taille = e.tailles[role]!;
    final f = await File(chemin).open();
    try {
      while (decalage < taille) {
        if (e.etat != EtatEnvoi.encours) return false;
        await f.setPosition(decalage);
        final octets = await f.read(morceau);
        try {
          final r = await Api.instance.morceau('envois/$id', decalage, octets);
          decalage = int.tryParse(r.entetes['upload-offset'] ?? '') ?? decalage + octets.length;
        } on ErreurApi catch (err) {
          // Le serveur n est pas ou on croyait : on lui redemande.
          if (err.code != 409) rethrow;
          decalage = int.tryParse((await Api.instance.head('envois/$id')).entetes['upload-offset'] ?? '') ?? 0;
        }
        e.recus[role] = decalage;
        _avanceDe(e);
        notifyListeners();
      }
    } finally {
      await f.close();
    }
    await Api.instance.post('envois/$id/terminer');
    e.termines.add(role);
    await _garder();
    return true;
  }

  void _avanceDe(Envoi e) {
    final total = e.tailles.values.fold<int>(0, (a, b) => a + b);
    final recu = e.recus.values.fold<int>(0, (a, b) => a + b);
    e
      ..avance = total == 0 ? 0 : (recu / total).clamp(0.0, 1.0)
      ..detail = null;
  }

  /// L analyse du serveur tourne encore.
  static String get enAnalyse => t('Vérification de la capture…');

  /// Pour l equipe : ce que la ligne dit, apres le motif eventuel.
  static String get pourLEquipe => t('L’équipe vérifie cette publication. Vous recevrez une notification dès sa décision.');

  // Les envois dont la decision est attendue en ce moment (pas deux fois a la fois).
  final _suivis = <Envoi>{};
  bool _actualise = false;

  // Toutes les 2 s pendant 80 s ; au-dela, Mes envois et le demarrage la redemandent.
  // `completee` : des informations viennent de partir, le serveur ne les a peut-etre
  // pas encore relues ; « a completer » ne compte pas pendant 20 s.
  Future<void> _attendreDecision(Envoi e, {bool completee = false}) async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final r = await Api.instance.get('contenus/${e.contenu}');
      if (_decision(e, (r.json['data'] as Map).cast<String, Object?>(), completee: completee && i < 10)) return;
      notifyListeners();
    }
  }

  /// Ce que le serveur a decide (GET contenus/{id}). Vrai si c est arrete : publiee,
  /// refusee, a completer, ou entre les mains de l equipe ; faux si l analyse tourne.
  bool _decision(Envoi e, Map<String, Object?> d, {bool completee = false}) {
    final motif = d['motif'] as String?;
    switch (d['statut']) {
      case 'publie':
        final verifiee = d['badge'] == 'verifiee';
        e
          ..etat = EtatEnvoi.publie
          ..attente = null
          ..motif = null
          ..detail = verifiee ? t('Publiée · Capture vérifiée') : t('Publiée · Informations déclarées');
        // Le badge du serveur remplace celui calcule sur le telephone.
        final l = e.locale;
        if (l != null) unawaited(MesPublications.instance.badge(l, verifiee: verifiee));
        // L accueil a neuf : la publication y prend sa place, a la place de la copie du telephone.
        unawaited(Catalogue.instance.rafraichir());
        return true;
      case 'refuse':
        _refuser(e, motif == null ? t('Refusée') : t('Refusée : {motif}', {'motif': motif}), motif: motif ?? t('La capture n’a pas été acceptée.'));
        return true;
      case 'file_humaine':
        e
          ..etat = EtatEnvoi.verification
          ..attente = 'file_humaine'
          ..detail = motif == null ? pourLEquipe : '$motif $pourLEquipe';
        return true;
      case 'a_completer':
        if (completee) return false;
        final manque = ((d['manque'] as List?) ?? const []).whereType<String>().toList();
        final telephone = manque.contains('telephone'), date = manque.contains('date');
        e
          ..etat = EtatEnvoi.verification
          ..attente = 'a_completer'
          ..detail = telephone && date
              ? t('Il manque le téléphone et la date de la prise.')
              : telephone
              ? t('Il manque le téléphone.')
              : date
              ? t('Il manque la date de la prise.')
              : t('Il manque des informations sur la prise.');
        e.manque
          ..clear()
          ..addAll(manque);
        return true;
      default:
        e
          ..attente = null
          ..detail = enAnalyse;
        return false;
    }
  }

  /// Les envois en verification redemandent leur decision au serveur (au demarrage,
  /// a l ouverture de Mes envois) : l analyse a pu finir, l equipe a pu trancher.
  Future<void> actualiser() async {
    if (_actualise || Api.instance.jeton == null) return;
    _actualise = true;
    var change = false;
    try {
      for (final e in [...liste]) {
        final c = e.contenu;
        if (e.etat != EtatEnvoi.verification || c == null || _suivis.contains(e)) continue;
        try {
          final r = await Api.instance.get('contenus/$c');
          _decision(e, (r.json['data'] as Map).cast<String, Object?>());
          change = true;
        } on ErreurApi catch (err) {
          if (err.code == 404) {
            _refuser(e, t('Cette publication n’est plus sur Discover.'));
            change = true;
          }
        } catch (_) {
          // Hors ligne : on redemandera.
        }
      }
    } finally {
      _actualise = false;
    }
    if (!change) return;
    notifyListeners();
    await _garder();
  }

  /// Completer une publication « a completer » : le telephone (marque et modele) et la date
  /// de la prise (PATCH contenus/{id}), puis l analyse repart. Nul si c est parti ; sinon
  /// ce qui n a pas abouti, a montrer tel quel.
  Future<String?> completer(Envoi e, {String? telephone, DateTime? date}) async {
    final c = e.contenu;
    if (c == null) return t('Cette publication n’est pas encore sur Discover.');
    // Comme a la creation : la marque est le premier mot.
    final tel = (telephone ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    final espace = tel.indexOf(' ');
    final corps = <String, Object?>{
      if (espace > 0) ...{'marque': tel.substring(0, espace), 'modele': tel.substring(espace + 1)},
      if (date != null) 'prise_le': date.toUtc().toIso8601String(),
    };
    if (corps.isEmpty) return t('Indiquez ce qui manque.');
    try {
      await Api.instance.patch('contenus/$c', corps);
    } on ApiInjoignable {
      return t('Aucune connexion. Réessayez dans un instant.');
    } on ErreurApi catch (err) {
      return err.erreurs.values.firstOrNull ?? err.message;
    }
    e
      ..attente = null
      ..detail = enAnalyse;
    e.manque.clear();
    notifyListeners();
    unawaited(_garder());
    if (_suivis.add(e)) {
      _attendreDecision(e, completee: true).catchError((Object _) {}).whenComplete(() {
        _suivis.remove(e);
        notifyListeners();
        _garder();
      });
    }
    return null;
  }

  /// Une publication refusee par le serveur : son auteur demande une seconde verification,
  /// par l equipe (une seule fois). La reponse du serveur, a montrer telle quelle.
  Future<({bool ok, String message})> demanderVerification(String contenu) async {
    try {
      final r = await Api.instance.post('contenus/${Uri.encodeComponent(contenu)}/verification');
      for (final e in liste.where((x) => x.contenu == contenu)) {
        e
          ..etat = EtatEnvoi.verification
          ..attente = 'file_humaine'
          ..motif = null
          ..detail = pourLEquipe;
      }
      notifyListeners();
      unawaited(_garder());
      return (ok: true, message: (r.json['message'] as String?) ?? t('Demande envoyée à l’équipe.'));
    } on ApiInjoignable {
      return (ok: false, message: t('Aucune connexion. Réessayez dans un instant.'));
    } on ErreurApi catch (err) {
      return (ok: false, message: err.message);
    }
  }

  void _enPause(Envoi e, String pourquoi, {Duration apres = const Duration(seconds: 15)}) {
    e
      ..etat = EtatEnvoi.pause
      ..detail = pourquoi;
    // Un nouvel essai dans 15 secondes : le reseau revient souvent vite.
    _reprise?.cancel();
    _reprise = Timer(apres, () {
      for (final x in liste) {
        if (x.source != null && x.etat == EtatEnvoi.pause && x.detail != null && x.detail != reconnecter) x.etat = EtatEnvoi.encours;
      }
      notifyListeners();
      _suivant();
    });
  }

  // `motif` : celui du serveur, s il a refuse lui-meme (une seconde verification se demande alors).
  void _refuser(Envoi e, String detail, {String? motif}) {
    e
      ..etat = EtatEnvoi.refuse
      ..avance = 1
      ..attente = null
      ..motif = motif
      ..detail = detail;
    // Refusee : elle ne reste pas dans mes publications.
    final l = e.locale;
    if (l != null) MesPublications.instance.retirer(l);
  }

  static String _type(String chemin, bool video) {
    final c = chemin.toLowerCase();
    if (video) return c.endsWith('.mov') ? 'video/quicktime' : 'video/mp4';
    if (c.endsWith('.webp')) return 'image/webp';
    if (c.endsWith('.png')) return 'image/png';
    if (c.endsWith('.heic') || c.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  @visibleForTesting
  void arreter() {
    _reprise?.cancel();
  }
}
