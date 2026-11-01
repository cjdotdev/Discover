import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E30 Indiquer le lieu. Voir repartition.md.
class EcranIndiquerLieu extends StatelessWidget {
  const EcranIndiquerLieu({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E30', nom: 'Indiquer le lieu', responsable: 'Ainé Mao');
  }
}
