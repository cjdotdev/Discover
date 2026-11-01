import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E32 Autorisations. Voir repartition.md.
class EcranAutorisations extends StatelessWidget {
  const EcranAutorisations({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E32', nom: 'Autorisations', responsable: 'Ainé Mao');
  }
}
