import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/mesures.dart';
import '../theme/textes.dart';
import 'icone.dart';

/// Se tasse un peu sous le doigt : le retour d'appui de tous les boutons.
class Appuyable extends StatefulWidget {
  const Appuyable({super.key, required this.child, required this.onTap, this.semantique});

  final Widget child;
  final VoidCallback? onTap;
  final String? semantique;

  @override
  State<Appuyable> createState() => _AppuyableState();
}

class _AppuyableState extends State<Appuyable> {
  bool _appuye = false;

  void _changer(bool appuye) => setState(() => _appuye = appuye);

  @override
  Widget build(BuildContext context) {
    final actif = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: actif,
      label: widget.semantique,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: actif ? (_) => _changer(true) : null,
        onTapUp: actif ? (_) => _changer(false) : null,
        onTapCancel: () => _changer(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _appuye ? 0.97 : 1,
          duration: Durees.appui,
          curve: Courbes.interface,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Le bouton de l'application. `principal` : l'action de la page, en bleu océan.
class Bouton extends StatelessWidget {
  const Bouton({
    super.key,
    required this.texte,
    required this.onTap,
    this.principal = true,
    this.fleche = false,
    this.chargement = false,
    this.icone,
  });

  final String texte;
  final VoidCallback? onTap;
  final bool principal;
  final bool fleche;
  final bool chargement;

  /// Un widget à gauche du texte (le G de Google, par exemple).
  final Widget? icone;

  @override
  Widget build(BuildContext context) {
    final encre = principal ? Colors.white : Couleurs.texte;
    return Appuyable(
      onTap: chargement ? null : onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.38 : 1,
        duration: Durees.interface,
        child: Container(
          height: Mesures.hautBouton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: principal ? Couleurs.ocean : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(Mesures.rayonBouton),
          ),
          child: chargement
              ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: encre))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icone != null) ...[icone!, const SizedBox(width: 10)],
                    Text(texte, style: Textes.bouton.copyWith(color: encre)),
                    if (fleche) ...[const SizedBox(width: 10), Icone('fleche-droite', taille: 18, couleur: encre)],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Le bouton rond de la maquette : retour, loupe, cloche.
class BoutonRond extends StatelessWidget {
  const BoutonRond({super.key, required this.icone, required this.onTap, required this.semantique});

  final String icone;
  final VoidCallback? onTap;
  final String semantique;

  @override
  Widget build(BuildContext context) {
    return Appuyable(
      onTap: onTap,
      semantique: semantique,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), shape: BoxShape.circle),
        child: Icone(icone, taille: 22, couleur: Couleurs.texte),
      ),
    );
  }
}

/// Un lien : du texte qu'on peut toucher.
class Lien extends StatelessWidget {
  const Lien(this.texte, {super.key, required this.onTap, this.discret = false});

  final String texte;
  final VoidCallback? onTap;
  final bool discret;

  @override
  Widget build(BuildContext context) {
    return Appuyable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(texte, style: discret ? Textes.lien.copyWith(color: Couleurs.discret) : Textes.lien),
      ),
    );
  }
}
