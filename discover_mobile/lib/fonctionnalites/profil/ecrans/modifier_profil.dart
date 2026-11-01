import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E21 Modifier le profil. Voir repartition.md.
class EcranModifierProfil extends StatelessWidget {
  const EcranModifierProfil({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E21', nom: 'Modifier le profil', responsable: 'Ainé Mao');
  }
}
