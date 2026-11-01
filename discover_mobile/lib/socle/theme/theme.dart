import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'couleurs.dart';

// Le thème commun à tous les écrans : la police Wura Mi, le fond et le glissement entre les pages.
ThemeData themeDiscover() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'WuraMi',
    scaffoldBackgroundColor: Couleurs.fond,
    colorScheme: const ColorScheme.light(
      primary: Couleurs.ocean,
      secondary: Couleurs.limonade,
      surface: Couleurs.fond,
      error: Couleurs.erreur,
      onSurface: Couleurs.texte,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
