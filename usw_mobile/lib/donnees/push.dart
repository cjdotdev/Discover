// Les notifications sur le telephone (Firebase Cloud Messaging) : ce telephone
// s enregistre aupres du serveur (PUT moi/push) avec les choix des reglages,
// gardes ici. Une notification touchee ouvre le centre des notifications.
// Sans google-services.json (et dans les tests), rien ne s active : les
// notifications restent dans l application.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Le jeton FCM classique (getToken), que l API HTTP v1 du serveur vise : les nouvelles
// adresses FID (register) ne sont pas encore prises par l envoi du serveur.
// ignore_for_file: deprecated_member_use
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/api.dart';
import 'communaute.dart';

class Push {
  Push._();
  static final instance = Push._();

  static const _cle = 'reglages_notifications';

  /// « Autoriser les notifications », le premier interrupteur des reglages.
  bool actives = true;

  /// « Tout mettre en pause 8 h » : jusqu a quand.
  DateTime? pauseJusqua;

  /// Ce qui envoie une notification (les lignes des reglages) ; « retiree » ne se coupe pas.
  final choix = <String, bool>{'jaime': true, 'commentaires': true, 'mentions': true, 'abonnes': true, 'verifiee': true, 'suivis': false};

  bool get enPause => pauseJusqua?.isAfter(DateTime.now()) ?? false;

  /// Android refuse les notifications a Discover (sa permission, dans ses reglages).
  bool bloqueesParAndroid = false;

  /// Ouvrir un ecran (le routeur de l application, branche par AppUsw).
  void Function(String chemin)? ouvrir;

  bool _pret = false;
  String? _jeton;
  bool _accueilAtteint = false;
  String? _toucheeEnAttente;

  Future<void> charger() async {
    try {
      final brut = (await SharedPreferences.getInstance()).getString(_cle);
      if (brut == null) return;
      final j = (jsonDecode(brut) as Map).cast<String, dynamic>();
      actives = j['actives'] as bool? ?? true;
      pauseJusqua = DateTime.tryParse(j['pause'] as String? ?? '');
      for (final e in ((j['choix'] as Map?) ?? const {}).entries) {
        if (choix.containsKey(e.key)) choix[e.key as String] = e.value == true;
      }
    } catch (_) {}
  }

  /// Au lancement : Firebase, l ecoute des notifications, puis l enregistrement (connecte).
  Future<void> demarrer() async {
    if (_pret || !Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      return;
    }
    _pret = true;
    final m = FirebaseMessaging.instance;
    m.onTokenRefresh.listen((jeton) {
      _jeton = jeton;
      enregistrer().ignore();
    });
    // L application ouverte : Android n affiche rien, le point des non lues se met a jour.
    FirebaseMessaging.onMessage.listen((_) => Communaute.instance.rafraichirNonLues().ignore());
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _touchee());
    if (await m.getInitialMessage() != null) _touchee();
    await enregistrer();
  }

  void _touchee() => toucher('/notifications');

  /// Une notification touchee (d activite, de telechargement) : sa page, tout de suite si
  /// Discover est deja a l accueil, sinon des qu il y arrive.
  void toucher(String page) {
    final aller = ouvrir;
    if (_accueilAtteint && aller != null) {
      aller(page);
    } else {
      _toucheeEnAttente = page;
    }
  }

  /// L ouverture est passee : la page d une notification touchee qui attend, s il y en a une.
  String? arrive() {
    _accueilAtteint = true;
    final attend = _toucheeEnAttente;
    _toucheeEnAttente = null;
    return attend;
  }

  /// Un reglage a change : il est garde, puis le serveur le sait.
  Future<void> changer() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_cle, jsonEncode({'actives': actives, 'pause': pauseJusqua?.toIso8601String(), 'choix': choix}));
    } catch (_) {}
    await (actives ? enregistrer() : oublier());
  }

  /// Ce telephone recoit les notifications de ce compte (apres la connexion, a chaque reglage).
  Future<void> enregistrer() async {
    if (!_pret || Api.instance.jeton == null) return;
    if (!actives) return oublier();
    try {
      final m = FirebaseMessaging.instance;
      // Android 13 et plus demandent la permission, une fois.
      final reglage = await m.requestPermission();
      bloqueesParAndroid = reglage.authorizationStatus == AuthorizationStatus.denied;
      if (bloqueesParAndroid) return;
      final jeton = _jeton ??= await m.getToken();
      if (jeton == null) return;
      await Api.instance.put('moi/push', {'jeton': jeton, 'preferences': choix, 'pause_jusqu_a': enPause ? pauseJusqua!.toUtc().toIso8601String() : null});
    } catch (_) {}
  }

  /// La permission d Android relue (au retour de ses reglages) : rendue, ce telephone s enregistre.
  Future<void> lirePermission() async {
    if (!_pret) return;
    try {
      final r = await FirebaseMessaging.instance.getNotificationSettings();
      final avant = bloqueesParAndroid;
      bloqueesParAndroid = r.authorizationStatus == AuthorizationStatus.denied;
      if (avant && !bloqueesParAndroid && actives) await enregistrer();
    } catch (_) {}
  }

  /// Ce telephone ne recoit plus rien (notifications coupees).
  Future<void> oublier() async {
    if (!_pret || Api.instance.jeton == null) return;
    try {
      final jeton = _jeton ??= await FirebaseMessaging.instance.getToken();
      if (jeton != null) await Api.instance.delete('moi/push?jeton=${Uri.encodeQueryComponent(jeton)}');
    } catch (_) {}
  }
}
