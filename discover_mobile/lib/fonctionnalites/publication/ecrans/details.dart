import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E14 Détails. Voir repartition.md.
class EcranDetails extends StatelessWidget {
  const EcranDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E14', nom: 'Détails', responsable: 'Ainé Mao');
  }
}
