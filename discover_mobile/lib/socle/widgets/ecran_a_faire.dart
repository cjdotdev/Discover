import 'package:flutter/material.dart';

import '../theme/textes.dart';

/// Un écran encore à réaliser. Il garde la navigation complète en attendant :
/// son responsable remplace ce widget par le vrai écran, dans le même fichier.
class EcranAFaire extends StatelessWidget {
  const EcranAFaire({super.key, required this.code, required this.nom, required this.responsable});

  final String code;
  final String nom;
  final String responsable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(code, style: Textes.titre),
            const SizedBox(height: 8),
            Text(nom, style: Textes.sousTitre, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('À réaliser par $responsable', style: Textes.discret),
          ],
        ),
      ),
    );
  }
}
