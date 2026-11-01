import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E05 Photo. Voir repartition.md.
class EcranPhoto extends StatelessWidget {
  const EcranPhoto({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E05', nom: 'Photo', responsable: 'Djamal');
  }
}
