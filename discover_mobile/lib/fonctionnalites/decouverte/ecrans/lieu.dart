import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E33 Lieu. Voir repartition.md.
class EcranLieu extends StatelessWidget {
  const EcranLieu({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E33', nom: 'Lieu', responsable: 'Joël');
  }
}
