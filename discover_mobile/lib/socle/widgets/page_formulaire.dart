import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/mesures.dart';
import '../theme/textes.dart';
import 'bouton.dart';

/// La mise en page des formulaires du compte : retour en haut, titre centré, contenu au milieu,
/// un mot au pied. Sur une tablette, le contenu garde la largeur d'un téléphone.
class PageFormulaire extends StatelessWidget {
  const PageFormulaire({
    super.key,
    required this.titre,
    this.sousTitre,
    required this.children,
    this.pied,
    this.entete,
  });

  final String titre;
  final Widget? sousTitre;
  final List<Widget> children;
  final Widget? pied;

  /// Ce qui passe au-dessus du titre (la pastille de l'e-mail).
  final Widget? entete;

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: marge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              if (context.canPop()) BoutonRond(icone: 'retour', semantique: 'Retour', onTap: () => context.pop()),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Mesures.largeurFormulaire),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (entete != null) ...[Center(child: entete), const SizedBox(height: 20)],
                          Text(titre, style: Textes.titre, textAlign: TextAlign.center),
                          if (sousTitre != null) ...[
                            const SizedBox(height: 10),
                            DefaultTextStyle(style: Textes.discret, textAlign: TextAlign.center, child: sousTitre!),
                          ],
                          const SizedBox(height: 24),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (pied != null) Center(child: pied),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
