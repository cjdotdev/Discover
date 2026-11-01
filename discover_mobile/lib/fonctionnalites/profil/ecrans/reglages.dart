import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E21 Réglages. Voir repartition.md.
class EcranReglages extends StatelessWidget {
  const EcranReglages({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E21', nom: 'Réglages', responsable: 'Ainé Mao');
  }
}
