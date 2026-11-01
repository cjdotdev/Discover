import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E07 Commentaires. Voir repartition.md.
class EcranCommentaires extends StatelessWidget {
  const EcranCommentaires({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E07', nom: 'Commentaires', responsable: 'Djamal');
  }
}
