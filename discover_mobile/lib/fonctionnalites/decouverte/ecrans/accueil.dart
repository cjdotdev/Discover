import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E03 Accueil. Voir repartition.md.
class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E03', nom: 'Accueil', responsable: 'Joël');
  }
}
