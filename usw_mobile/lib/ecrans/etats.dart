// E37 Les etats : pas de connexion, contenu introuvable, publication refusee.
// Un ecran calme : une icone dans sa tuile, un titre, une phrase, une ou deux
// actions. Tout tient sans defiler.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../donnees/communaute.dart';
import '../donnees/envois.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/verre.dart';

class EcranEtat extends StatefulWidget {
  const EcranEtat({super.key, required this.etat, this.titre, this.motif, this.contenu});

  /// hors-ligne, introuvable ou refusee.
  final String etat;

  /// Le nom de la publication refusee.
  final String? titre;

  /// Le motif du refus, tel que le serveur (ou le telephone) l a donne.
  final String? motif;

  /// La publication refusee par le serveur : une seconde verification peut se demander.
  final String? contenu;

  @override
  State<EcranEtat> createState() => _EcranEtatState();
}

class _EcranEtatState extends State<EcranEtat> {
  bool _demande = false;

  // POST contenus/{id}/verification : la publication repasse devant l equipe (une seule fois).
  Future<void> _demanderVerification(VoidCallback retour) async {
    final contenu = widget.contenu;
    if (contenu == null || _demande) return;
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour demander une vérification.'), icone: 'profil');
      return;
    }
    setState(() => _demande = true);
    final r = await Envois.instance.demanderVerification(contenu);
    if (!mounted) return;
    setState(() => _demande = false);
    bulle(context, r.message, icone: r.ok ? 'bouclier' : 'alerte');
    if (r.ok) retour();
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback retour = context.canPop() ? () => context.pop() : () => context.go('/accueil');
    final titre = widget.titre ?? t('Votre publication');
    final motif = widget.motif;
    final (icone, titreEtat, texte, danger) = switch (widget.etat) {
      'hors-ligne' => ('hors-ligne', t('Aucune connexion'), t('Les photos déjà vues restent disponibles. Vos publications seront envoyées dès que la connexion sera rétablie.'), false),
      'refusee' => (
        'drapeau',
        t('Publication refusée'),
        [
          motif == null ? t('« {titre} » n’a pas été acceptée.', {'titre': titre}) : t('« {titre} » n’a pas été acceptée. Motif : {motif}', {'titre': titre, 'motif': motif}),
          if (widget.contenu != null) t('S’il s’agit d’une vraie photo, vous pouvez demander à l’équipe une seconde vérification.'),
        ].join('\n\n'),
        true,
      ),
      _ => ('image-barre', t('Cette photo n’est plus disponible'), t('Son auteur l’a retirée, ou le lien est incomplet.'), false),
    };
    final actions = switch (widget.etat) {
      'hors-ligne' => [
        BoutonVerre(texte: t('Voir les photos enregistrées'), plein: true, onTap: () => context.go('/profil')),
        const SizedBox(height: 10),
        BoutonVerre(texte: t('Réessayer'), onTap: retour),
      ],
      'refusee' => [
        if (widget.contenu != null) ...[
          BoutonVerre(texte: t('Demander une vérification'), plein: true, enCours: _demande, onTap: _demande ? null : () => _demanderVerification(retour)),
          const SizedBox(height: 10),
        ],
        BoutonVerre(texte: t('Lire les règles'), plein: widget.contenu == null, onTap: () => context.push('/document/regles')),
      ],
      _ => [BoutonVerre(texte: t('Revenir à l’accueil'), plein: true, onTap: () => context.go('/accueil'))],
    };
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(marge, 8, marge, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: retour),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: danger ? Couleurs.erreur.withValues(alpha: 0.12) : Couleurs.surface.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(24)),
                          child: Icone(icone, taille: 36, couleur: danger ? Couleurs.erreur : Couleurs.texte),
                        ),
                        const SizedBox(height: 18),
                        Titre(titreEtat, style: Textes.titre.copyWith(fontSize: 26), centre: true),
                        const SizedBox(height: 10),
                        Text(texte, textAlign: TextAlign.center, style: Textes.discret),
                        const SizedBox(height: 26),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un onglet sans rien a montrer (pas de reseau, pas de compte, rien encore) :
/// la meme tuile, un titre, une phrase, une action. Il se pose au milieu.
class EtatVide extends StatelessWidget {
  const EtatVide({super.key, required this.icone, required this.titre, required this.texte, this.action, this.onAction, this.sombre = false});

  final String icone;
  final String titre;
  final String texte;
  final String? action;
  final VoidCallback? onAction;

  /// Sur le fond noir des reels.
  final bool sombre;

  @override
  Widget build(BuildContext context) {
    final encre = sombre ? Colors.white : Couleurs.texte;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: sombre ? Colors.white.withValues(alpha: 0.12) : Couleurs.surface.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(22)),
                child: Icone(icone, taille: 32, couleur: encre),
              ),
              const SizedBox(height: 16),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: encre),
              ),
              if (texte.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  texte,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4, color: sombre ? Colors.white70 : Couleurs.discret),
                ),
              ],
              if (action != null && onAction != null) ...[const SizedBox(height: 20), BoutonVerre(texte: action!, plein: true, onTap: onAction!)],
            ],
          ),
        ),
      ),
    );
  }
}
