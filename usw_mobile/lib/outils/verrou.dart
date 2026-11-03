// Le verrou des collections secretes : l empreinte du telephone (ou son code, son schema),
// une fois par visite. Le serveur les cache deja aux autres comptes ; ce verrou les garde
// de quelqu un qui tiendrait ce telephone deverrouille. Discover quitte l ecran plus d une
// minute (ou le compte change) : elles se reverrouillent.
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../widgets/banniere.dart';
import 'langue.dart';

class Verrou extends ChangeNotifier {
  // L ecran du code du telephone cache Discover un instant : ce depart-la ne compte pas.
  Verrou._() {
    AppLifecycleListener(
      onHide: () {
        if (!_enCours) _parti ??= DateTime.now();
      },
      onShow: () {
        final parti = _parti;
        _parti = null;
        if (parti != null && DateTime.now().difference(parti) >= _absenceTolere) fermer();
      },
    );
  }
  static final instance = Verrou._();

  static const _absenceTolere = Duration(minutes: 1);

  bool _ouvert = false;
  bool _enCours = false;
  DateTime? _parti;

  /// Les collections secretes sont deverrouillees pour cette visite.
  bool get ouvert => _ouvert;

  /// Demande l empreinte (ou le code du telephone) ; vrai si c est bien la personne.
  /// Un telephone sans verrouillage d ecran ne peut rien verifier : la collection s ouvre,
  /// et la bulle conseille d en mettre un.
  Future<bool> ouvrir(BuildContext context) async {
    if (_ouvert) return true;
    if (_enCours) return false;
    _enCours = true;
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported()) {
        if (context.mounted) bulle(context, t('Pour protéger vos collections secrètes, configurez le verrouillage de l’écran de ce téléphone.'), icone: 'cadenas');
        _ouvert = true;
      } else {
        _ouvert = await auth.authenticate(localizedReason: t('Ouvrir vos collections secrètes'), biometricOnly: false);
      }
    } catch (_) {
      if (context.mounted) bulle(context, t('Impossible de vérifier votre identité sur ce téléphone.'), icone: 'cadenas');
    } finally {
      _enCours = false;
    }
    if (_ouvert) notifyListeners();
    return _ouvert;
  }

  /// Reverrouiller (Discover quitte l ecran, le compte change).
  void fermer() {
    if (!_ouvert) return;
    _ouvert = false;
    notifyListeners();
  }
}
