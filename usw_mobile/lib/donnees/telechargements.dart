// Les telechargements vers la galerie : chacun avance dans une notification du telephone
// (sa barre), et dans Mes envois (Telechargements), ou ils restent ensuite, les plus
// recents d abord. La liste est gardee sur le telephone (50 au plus).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/galerie.dart';
import '../outils/langue.dart';
import 'push.dart';

enum EtatTelechargement { encours, ok, echec }

class Telecharge {
  Telecharge({required this.id, required this.titre, required this.photo, required this.video, required this.date, this.contenu, this.taille, this.etat = EtatTelechargement.encours});

  final int id;
  final String titre;

  /// La vignette (une petite taille, ou le fichier du telephone).
  final String photo;
  final bool video;
  final String? contenu;

  /// La taille choisie (« 3840 », « 2160 », « video-1080 »…) ; nulle, la plus grande.
  final String? taille;
  final DateTime date;
  EtatTelechargement etat;

  /// De 0 a 1 pendant le telechargement.
  double avance = 0;

  /// Galerie refusee : le message le dit, et le reglage du telephone y remedie.
  bool galerieRefusee = false;

  Map<String, Object?> versJson() => {'id': id, 'titre': titre, 'photo': photo, 'video': video, 'contenu': contenu, 'taille': taille, 'date': date.toIso8601String(), 'etat': etat.name};

  static Telecharge? depuisJson(Map<String, Object?> j) {
    final date = DateTime.tryParse(j['date'] as String? ?? '');
    if (date == null) return null;
    return Telecharge(
      id: (j['id'] as num?)?.toInt() ?? 0,
      titre: j['titre'] as String? ?? '',
      photo: j['photo'] as String? ?? '',
      video: j['video'] == true,
      contenu: j['contenu'] as String?,
      taille: j['taille'] as String?,
      date: date,
      // Coupe en route (l application fermee) : il n a pas abouti.
      etat: EtatTelechargement.values.asNameMap()[j['etat']] == EtatTelechargement.ok ? EtatTelechargement.ok : EtatTelechargement.echec,
    );
  }
}

class Telechargements extends ChangeNotifier {
  Telechargements._();
  static final instance = Telechargements._();

  static const _cle = 'telechargements';
  static const _canal = MethodChannel('bj.usw/telechargements');
  static const _plafond = 50;

  final liste = <Telecharge>[];
  bool _charge = false;

  /// Au demarrage : une notification de telechargement touchee ouvre Mes envois et
  /// telechargements (Discover deja ouvert, ou lance par elle).
  void ecouterNotifications() {
    _canal.setMethodCallHandler((appel) async {
      if (appel.method == 'ouvrir' && appel.arguments is String) Push.instance.toucher(appel.arguments as String);
    });
    _canal.invokeMethod<String>('ouvertureEnAttente').then((page) {
      if (page != null) Push.instance.toucher(page);
    }, onError: (_) {});
  }

  Future<void> charger() async {
    if (_charge) return;
    _charge = true;
    try {
      final brut = (await SharedPreferences.getInstance()).getString(_cle);
      if (brut == null) return;
      liste
        ..clear()
        ..addAll([for (final j in (jsonDecode(brut) as List).cast<Map>()) ?Telecharge.depuisJson(j.cast<String, Object?>())]);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _garder() async {
    try {
      final finis = liste.where((d) => d.etat != EtatTelechargement.encours).take(_plafond).map((d) => d.versJson()).toList();
      await (await SharedPreferences.getInstance()).setString(_cle, jsonEncode(finis));
    } catch (_) {}
  }

  /// Un autre compte sur ce telephone : la liste repart vide (les fichiers restent dans la galerie).
  void oublier() {
    liste.clear();
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.remove(_cle)).ignore();
  }

  /// Retirer un telechargement de la liste (le fichier reste dans la galerie).
  void retirer(Telecharge d) {
    liste.remove(d);
    notifyListeners();
    _garder();
  }

  /// Telecharger vers la galerie : la notification avance, puis dit le resultat.
  Future<Telecharge> lancer({required String titre, required String source, required String vignette, String? contenu, bool video = false, String? taille}) async {
    await charger();
    // (« d » : « t » est la traduction.)
    final d = Telecharge(id: DateTime.now().millisecondsSinceEpoch % 100000, titre: titre, photo: vignette, video: video, contenu: contenu, taille: taille, date: DateTime.now());
    liste.insert(0, d);
    notifyListeners();
    final enCours = video ? t('Téléchargement de la vidéo…') : t('Téléchargement de la photo…');
    // La premiere, en haut de l ecran : le telechargement a commence (comme WhatsApp).
    _canal.invokeMethod<void>('avance', {'id': d.id, 'titre': t('Téléchargement commencé'), 'texte': titre, 'pourcent': 0}).catchError((_) {});
    // Android ignore les mises a jour trop rapprochees d une notification (quelques-unes par
    // seconde) : la barre avance toutes les 0,5 s, et la fin attend son tour, sinon elle se
    // perdait et la notification restait « Téléchargement… » a 100 %.
    final depuis = Stopwatch()..start();
    var dernier = -1;
    var notifiee = Duration.zero;
    final resultat = await telechargerDansGalerie(
      source,
      contenu: contenu,
      video: video,
      taille: taille,
      avance: (a) {
        d.avance = a;
        final pourcent = (a * 100).floor();
        if (pourcent == dernier) return;
        dernier = pourcent;
        notifyListeners();
        if (depuis.elapsed - notifiee >= const Duration(milliseconds: 500)) {
          notifiee = depuis.elapsed;
          _notifier('avance', d, enCours, pourcent);
        }
      },
    );
    d.etat = resultat == Telechargement.ok ? EtatTelechargement.ok : EtatTelechargement.echec;
    d.galerieRefusee = resultat == Telechargement.galerieRefusee;
    if (d.etat == EtatTelechargement.ok) d.avance = 1;
    final attente = const Duration(milliseconds: 600) - (depuis.elapsed - notifiee);
    if (attente > Duration.zero) await Future<void>.delayed(attente);
    _notifier('fin', d, messageDe(d), 100);
    notifyListeners();
    await _garder();
    return d;
  }

  /// Ce que dit un telechargement fini, dans la notification et la bulle.
  static String messageDe(Telecharge d) => switch (d.etat) {
    EtatTelechargement.ok => d.video ? t('Vidéo téléchargée avec succès, dans l’album Discover.') : t('Photo téléchargée avec succès, dans l’album Discover.'),
    EtatTelechargement.echec when d.galerieRefusee => t('Discover n’a pas accès à la galerie. Autorisez l’accès dans les réglages du téléphone.'),
    EtatTelechargement.encours => d.video ? t('Téléchargement de la vidéo…') : t('Téléchargement de la photo…'),
    _ => t('Impossible de télécharger. Vérifiez votre connexion et l’accès à la galerie, puis réessayez.'),
  };

  void _notifier(String methode, Telecharge d, String texte, int pourcent) {
    _canal.invokeMethod<void>(methode, {'id': d.id, 'titre': d.titre, 'texte': texte, 'pourcent': pourcent}).catchError((_) {});
  }
}
