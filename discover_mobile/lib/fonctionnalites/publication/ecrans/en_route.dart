import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E16 En route. Voir repartition.md.
class EcranEnRoute extends StatelessWidget {
  const EcranEnRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E16', nom: 'En route', responsable: 'Ainé Mao');
  }
}
