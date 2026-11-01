import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E11 Carte. Voir repartition.md.
class EcranCarte extends StatelessWidget {
  const EcranCarte({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E11', nom: 'Carte', responsable: 'Djamal');
  }
}
