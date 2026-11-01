import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E20 Profil d'un créateur. Voir repartition.md.
class EcranCreateur extends StatelessWidget {
  const EcranCreateur({super.key, required this.nom});

  final String nom;

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E20', nom: 'Profil d\'un créateur', responsable: 'Joël');
  }
}
