// Mes publications : ce que le membre a publie depuis ce telephone, en tete
// de son profil (E18). Les fichiers sont copies dans le dossier d USW (le
// cache peut etre vide par Android) et la liste est gardee d une ouverture a
// l autre. Elles partent au serveur (envois.dart) ; une publication que le
// serveur ne connait plus (supprimee, ou envoyee a un ancien serveur) s en va.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/api.dart';
import '../outils/langue.dart';
import 'catalogue.dart';
import 'envois.dart';
import 'modeles.dart';
import 'session.dart';

class MaPublication {
  MaPublication({
    required this.photo,
    required this.lieu,
    required this.appareil,
    required this.verifiee,
    required this.date,
    this.video,
    this.dureeReel,
    this.legende = '',
    this.ratio = 0.75,
    this.priseAvecDiscover = false,
    this.lieuId,
    this.latitude,
    this.longitude,
    this.contenu,
  });

  /// Son identifiant sur le serveur, une fois l envoi parti : de quoi ne pas la montrer deux fois.
  String? contenu;

  /// Prise a l instant avec l appareil photo, depuis Discover. Une video ainsi
  /// tournee est un reel (les Reels) ; une video importee de la galerie va a
  /// l accueil, comme les photos.
  final bool priseAvecDiscover;

  /// Le lieu connu de Discover a moins de 2 km, s il y en a un.
  final String? lieuId;
  final double? latitude;
  final double? longitude;

  bool get estUnReel => video != null && priseAvecDiscover;

  /// L image ; pour un reel, sa couverture.
  final String photo;

  /// La video d un reel.
  final String? video;
  final int? dureeReel;
  final String lieu;
  final String legende;
  final String appareil;
  final bool verifiee;
  final DateTime date;

  /// La largeur sur la hauteur, pour la mosaique.
  final double ratio;

  Map<String, Object?> versJson() => {
    'photo': photo,
    'video': video,
    'dureeReel': dureeReel,
    'lieu': lieu,
    'legende': legende,
    'appareil': appareil,
    'verifiee': verifiee,
    'date': date.millisecondsSinceEpoch,
    'ratio': ratio,
    'priseAvecDiscover': priseAvecDiscover,
    'lieuId': lieuId,
    'latitude': latitude,
    'longitude': longitude,
    'contenu': contenu,
  };

  static MaPublication depuisJson(Map<String, Object?> j) => MaPublication(
    photo: j['photo'] as String,
    video: j['video'] as String?,
    dureeReel: (j['dureeReel'] as num?)?.toInt(),
    lieu: j['lieu'] as String? ?? '',
    legende: j['legende'] as String? ?? '',
    appareil: j['appareil'] as String? ?? '',
    verifiee: j['verifiee'] == true,
    date: DateTime.fromMillisecondsSinceEpoch((j['date'] as num?)?.toInt() ?? 0),
    ratio: (j['ratio'] as num?)?.toDouble() ?? 0.75,
    priseAvecDiscover: j['priseAvecDiscover'] == true,
    lieuId: j['lieuId'] as String?,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    contenu: j['contenu'] as String?,
  );
}

class MesPublications extends ChangeNotifier {
  MesPublications._();
  static final instance = MesPublications._();

  static const _cle = 'mes_publications';

  final liste = <MaPublication>[];

  /// Les videos tournees avec Discover : en tete des Reels. Un reel deja en ligne est celui
  /// du serveur (compteurs, badge, musique melee a la video, 1080p), comme pour les autres :
  /// la video d ici, brute (sans la musique), ne sert que tant que le serveur prepare la sienne.
  List<Reel> get reels => [
    for (final p in liste)
      if (p.estUnReel)
        if (Catalogue.instance.reels.where((r) => p.contenu != null && r.id == p.contenu).firstOrNull case final s?)
          Reel(
            photo: s.photo,
            pseudo: s.pseudo,
            nom: s.nom,
            legende: s.legende,
            appareil: s.appareil,
            lieu: s.lieu,
            lieuNom: s.lieuNom,
            latitude: s.latitude,
            longitude: s.longitude,
            duree: s.duree,
            jaime: s.jaime,
            commentaires: s.commentaires,
            enregistres: s.enregistres,
            partages: s.partages,
            vues: s.vues,
            son: s.son,
            video: s.video ?? (p.video != null && File(p.video!).existsSync() ? p.video : null),
            videoHd: s.videoHd,
            musiqueId: s.musiqueId,
            musiqueActive: s.musiqueActive,
            mien: true,
            id: s.id,
            maReaction: s.maReaction,
            verifiee: s.verifiee,
            avatar: s.avatar,
          )
        else
          Reel(
            photo: p.photo,
            pseudo: Session.instance.nomUtilisateur.isEmpty ? 'vous' : Session.instance.nomUtilisateur,
            nom: Session.instance.nomAffiche.isEmpty ? t('Vous') : Session.instance.nomAffiche,
            legende: p.legende,
            appareil: p.appareil,
            lieu: p.lieuId ?? 'mien-${p.date.millisecondsSinceEpoch}',
            lieuNom: p.lieu,
            latitude: p.latitude,
            longitude: p.longitude,
            duree: (p.dureeReel ?? 1).clamp(1, 600),
            jaime: 0,
            commentaires: 0,
            enregistres: 0,
            partages: 0,
            video: p.video,
            mien: true,
            id: p.contenu,
            verifiee: p.verifiee,
            avatar: Session.instance.photo ?? Session.instance.avatar,
          ),
  ];

  /// Les photos, et les videos importees : a l accueil.
  List<MaPublication> get pourAccueil => [
    for (final p in liste)
      if (!p.estUnReel) p,
  ];

  /// Un autre compte sur ce telephone : mes publications gardees ici ne passent pas au suivant.
  /// (Les photos de la galerie, elles, restent.)
  void oublier() {
    liste.clear();
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.remove(_cle)).ignore();
  }

  /// Au demarrage : les publications gardees, si leurs fichiers sont la.
  Future<void> charger() async {
    try {
      final brut = (await SharedPreferences.getInstance()).getString(_cle);
      if (brut == null) return;
      liste
        ..clear()
        ..addAll([
          for (final j in jsonDecode(brut) as List)
            if (File((j as Map<String, Object?>)['photo'] as String).existsSync()) MaPublication.depuisJson(j),
        ]);
      for (final p in liste) {
        ratiosFichiers[p.photo] = p.ratio;
        if (p.video != null) videosDesAffiches[p.photo] = p.video!;
      }
    } catch (_) {}
  }

  /// Les identifiants sur le serveur de mes publications locales.
  Set<String> get contenus => {
    for (final p in liste)
      if (p.contenu != null) p.contenu!,
  };

  /// L envoi a cree la publication sur le serveur : on retient son identifiant.
  Future<void> lier(String photo, String contenu) async {
    for (final p in liste) {
      if (p.photo == photo) p.contenu = contenu;
    }
    notifyListeners();
    await _garder();
  }

  /// Une publication refusee par le serveur (image d IA…) : elle quitte le profil.
  Future<void> retirer(String photo) async {
    liste.removeWhere((p) => p.photo == photo);
    notifyListeners();
    await _garder();
  }

  /// Ma publication par son identifiant sur le serveur.
  MaPublication? deContenu(String contenu) => liste.where((p) => p.contenu == contenu).firstOrNull;

  /// Le badge decide par le serveur (verifiee ou declaree) remplace celui calcule sur le telephone.
  Future<void> badge(String photo, {required bool verifiee}) async {
    final i = liste.indexWhere((p) => p.photo == photo);
    if (i < 0 || liste[i].verifiee == verifiee) return;
    liste[i] = MaPublication.depuisJson({...liste[i].versJson(), 'verifiee': verifiee});
    notifyListeners();
    await _garder();
  }

  /// Supprimer ma publication : son envoi s arrete, le serveur la retire, puis
  /// elle quitte le telephone. Faux si le serveur n a pas pu etre joint.
  Future<bool> supprimer({String? contenu, String? photo}) async {
    final locale = photo ?? (contenu == null ? null : deContenu(contenu)?.photo);
    for (final e in [...Envois.instance.liste]) {
      if (locale != null && e.locale == locale) Envois.instance.annuler(e);
    }
    if (contenu != null) {
      try {
        await Api.instance.delete('contenus/$contenu');
      } on ErreurApi catch (e) {
        // Deja partie du serveur : il ne reste qu a l oublier ici.
        if (e.code != 404) return false;
      } on ApiInjoignable {
        return false;
      }
      Catalogue.instance.oublierPublication(contenu);
    }
    liste.removeWhere((p) => (locale != null && p.photo == locale) || (contenu != null && p.contenu == contenu));
    notifyListeners();
    await _garder();
    return true;
  }

  /// Mes publications gardees ici que le serveur ne connait plus quittent le
  /// telephone (supprimees ailleurs, ou envoyees a un ancien serveur) : on ne
  /// pourrait ni y reagir ni les supprimer. Seulement si le serveur a tout donne.
  Future<void> accorderAuServeur() async {
    if (Api.instance.jeton == null || !liste.any((p) => p.contenu != null)) return;
    final connus = <String>{};
    try {
      String? curseur;
      do {
        final r = await Api.instance.get('moi/contenus${curseur == null ? '' : '?curseur=${Uri.encodeQueryComponent(curseur)}'}');
        connus.addAll([for (final c in (r.json['data'] as List? ?? []).cast<Map>()) c['id'] as String]);
        curseur = (r.json['meta'] as Map?)?['next_cursor'] as String?;
      } while (curseur != null);
    } catch (_) {
      return;
    }
    final avant = liste.length;
    liste.removeWhere((p) => p.contenu != null && !connus.contains(p.contenu));
    if (liste.length == avant) return;
    notifyListeners();
    await _garder();
  }

  Future<void> _garder() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_cle, jsonEncode([for (final p in liste) p.versJson()]));
    } catch (_) {}
  }

  static var _suivant = 0;

  /// Publie : les fichiers sont copies chez Discover, puis la publication passe en tete.
  Future<MaPublication> ajouter({
    required String photo,
    String? video,
    int? dureeReel,
    required String lieu,
    String legende = '',
    required String appareil,
    required bool verifiee,
    bool priseAvecDiscover = false,
    String? lieuId,
    double? latitude,
    double? longitude,
  }) async {
    String garde = photo;
    String? videoGardee = video;
    try {
      final dossier = Directory('${(await getApplicationDocumentsDirectory()).path}/publications');
      await dossier.create(recursive: true);
      // Un nom unique, meme pour dix publications lancees dans la meme milliseconde (le lot).
      final n = '${DateTime.now().microsecondsSinceEpoch}-${_suivant++}';
      // Copiee sans bloquer l interface : une video peut peser 150 Mo.
      Future<String> copier(String source, String nom) async {
        final extension = source.contains('.') ? source.substring(source.lastIndexOf('.')) : '';
        final cible = '${dossier.path}/$n-$nom$extension';
        await File(source).copy(cible);
        return cible;
      }

      garde = await copier(photo, 'photo');
      if (video != null) videoGardee = await copier(video, 'video');
    } catch (_) {}
    final ratio = await _ratio(garde);
    ratiosFichiers[garde] = ratio;
    if (videoGardee != null) videosDesAffiches[garde] = videoGardee;
    final nouvelle = MaPublication(
      photo: garde,
      video: videoGardee,
      dureeReel: dureeReel,
      lieu: lieu,
      legende: legende,
      appareil: appareil,
      verifiee: verifiee,
      date: DateTime.now(),
      ratio: ratio,
      priseAvecDiscover: priseAvecDiscover,
      lieuId: lieuId,
      latitude: latitude,
      longitude: longitude,
    );
    liste.insert(0, nouvelle);
    notifyListeners();
    await _garder();
    return nouvelle;
  }

  // Le sens de la photo, une fois tournee comme il faut : decodee en tout petit.
  Future<double> _ratio(String chemin) async {
    try {
      final codec = await ui.instantiateImageCodec(await File(chemin).readAsBytes(), targetWidth: 48);
      final image = (await codec.getNextFrame()).image;
      final r = image.width / image.height;
      image.dispose();
      codec.dispose();
      return r.clamp(0.5, 1.5);
    } catch (_) {
      return 0.75;
    }
  }
}
