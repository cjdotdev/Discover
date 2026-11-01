import 'package:flutter/material.dart';

import '../../../socle/widgets/ecran_a_faire.dart';

/// E17 Notifications. Voir repartition.md.
class EcranNotifications extends StatelessWidget {
  const EcranNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    return const EcranAFaire(code: 'E17', nom: 'Notifications', responsable: 'Joël');
  }
}
