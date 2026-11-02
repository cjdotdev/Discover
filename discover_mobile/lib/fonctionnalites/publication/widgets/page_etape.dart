import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../decouverte/widgets/verre.dart';

/// Une étape de la publication (reprise de la PageFormulaire de usw_mobile, contenu
/// en haut) : le retour, un titre court au centre s'il y en a un, le contenu qui
/// défile, et le pied (le bouton de l'étape) en bas de l'écran.
class PageEtape extends StatelessWidget {
  const PageEtape({super.key, required this.enfants, required this.pied, this.titre});

  final List<Widget> enfants;
  final Widget pied;

  /// Un titre court au centre de la ligne du haut (« Nouvelle publication »).
  final String? titre;

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(marge, 8, marge, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Mesures.largeurFormulaire),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RondVerre(
                        icone: 'retour',
                        semantique: 'Retour',
                        onTap: () => context.canPop() ? context.pop() : context.go(Routes.creer),
                      ),
                      if (titre != null) ...[
                        Expanded(
                          child: Text(
                            titre!,
                            textAlign: TextAlign.center,
                            style: Textes.libelle.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants),
                    ),
                  ),
                  const SizedBox(height: 16),
                  pied,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
