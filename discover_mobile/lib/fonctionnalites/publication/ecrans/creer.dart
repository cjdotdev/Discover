import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E12 Créer. Voir repartition.md.
class EcranCreer extends StatelessWidget {
  const EcranCreer({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E12', nom: 'Créer', responsable: 'Ainé Mao');
  }
}
