import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/textes.dart';
import 'bouton.dart';
import 'icone.dart';

/// E37, la bulle : un court message en bas de l'écran après une action.
void bulle(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: Textes.corps.copyWith(color: Colors.white)),
        backgroundColor: Couleurs.texte,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}

/// E37, la fenêtre de confirmation : renvoie vrai si le membre confirme.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String texte,
  required String action,
}) async {
  final reponse = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Couleurs.surface,
      title: Text(titre, style: Textes.sousTitre),
      content: Text(texte, style: Textes.discret),
      actions: [
        Lien('Annuler', discret: true, onTap: () => Navigator.pop(context, false)),
        const SizedBox(width: 8),
        Lien(action, onTap: () => Navigator.pop(context, true)),
      ],
    ),
  );
  return reponse ?? false;
}

/// E37, un écran d'état : hors connexion, contenu introuvable, recherche vide…
class EtatMessage extends StatelessWidget {
  const EtatMessage({
    super.key,
    required this.icone,
    required this.titre,
    required this.texte,
    this.action,
    this.surAction,
  });

  /// Le cas le plus courant : pas de réseau.
  const EtatMessage.horsLigne({super.key, required this.surAction})
    : icone = 'hors-ligne',
      titre = 'Aucune connexion',
      texte = 'Vérifiez le réseau, puis réessayez.',
      action = 'Réessayer';

  final String icone;
  final String titre;
  final String texte;
  final String? action;
  final VoidCallback? surAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icone(icone, taille: 44, couleur: Couleurs.discret),
            const SizedBox(height: 16),
            Text(titre, style: Textes.sousTitre, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(texte, style: Textes.discret, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 20),
              Bouton(texte: action!, onTap: surAction, principal: false),
            ],
          ],
        ),
      ),
    );
  }
}
