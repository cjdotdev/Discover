import 'package:flutter/material.dart';

import 'app.dart';
import 'socle/session/session.dart';

// Le point de départ : on relit la session gardée sur le téléphone, puis on lance l'application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.instance.charger();
  runApp(const DiscoverApp());
}
