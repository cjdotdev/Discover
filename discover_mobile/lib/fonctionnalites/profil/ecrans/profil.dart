import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E18 Mon profil. Voir repartition.md.
class EcranProfil extends StatelessWidget {
  const EcranProfil({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E18', nom: 'Mon profil', responsable: 'Ainé Mao');
  }
}
