import 'package:flutter/material.dart';

import 'socle/navigation/routeur.dart';
import 'socle/theme/theme.dart';

// L'application : le thème et la navigation. Tout le reste est dans les écrans.
class DiscoverApp extends StatelessWidget {
  const DiscoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Discover',
      debugShowCheckedModeBanner: false,
      theme: themeDiscover(),
      routerConfig: routeur,
    );
  }
}
