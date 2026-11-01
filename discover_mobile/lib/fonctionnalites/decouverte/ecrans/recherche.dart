import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E31 Recherche. Voir repartition.md.
class EcranRecherche extends StatelessWidget {
  const EcranRecherche({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E31', nom: 'Recherche', responsable: 'Joël');
  }
}
