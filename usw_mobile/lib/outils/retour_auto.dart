// Le retour tout seul apres la prise : une fois, avant d ouvrir l appareil photo du telephone,
// Discover propose de s afficher par-dessus les autres applis. Autorise, il revient de lui-meme
// des que la photo ou la video est enregistree (Appareil.kt) ; sinon, on revient avec le bouton
// retour, comme avant. Android n autorise pas autre chose a une app en arriere-plan.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/feuille.dart';
import 'appareil.dart';
import 'langue.dart';

const _cle = 'retour_auto_propose';

Future<void> proposerRetourAuto(BuildContext context) async {
  if (!Platform.isAndroid || await Appareil.retourAuto()) return;
  try {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_cle) ?? false) return;
    await preferences.setBool(_cle, true);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  final oui = await confirmer(
    context,
    titre: t('Revenir tout seul après la prise'),
    texte: t('Autorisez Discover à s’afficher par-dessus les autres applis : dès que la photo ou la vidéo est enregistrée, Discover revient tout seul avec elle.'),
    action: t('Autoriser'),
    icone: 'camera',
    danger: false,
  );
  if (!oui) return;
  // La page d Android s ouvre ; on attend le retour dans Discover (2 minutes au plus).
  final retour = Completer<void>();
  final ecoute = AppLifecycleListener(
    onResume: () {
      if (!retour.isCompleted) retour.complete();
    },
  );
  await Appareil.demanderRetourAuto();
  await retour.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  ecoute.dispose();
}
