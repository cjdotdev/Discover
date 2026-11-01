import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/couleurs.dart';
import '../widgets/bouton.dart';
import '../widgets/icone.dart';

/// La barre d'onglets flottante : Accueil, Reels, Créer, Carte, Profil.
/// Chaque onglet garde sa page et son défilement quand on change d'onglet.
class CoquilleOnglets extends StatelessWidget {
  const CoquilleOnglets({super.key, required this.coquille});

  final StatefulNavigationShell coquille;

  static const _onglets = [
    (icone: 'accueil', plein: 'accueil-plein', nom: 'Accueil'),
    (icone: 'reels', plein: 'reels-plein', nom: 'Reels'),
    (icone: 'plus', plein: 'plus', nom: 'Créer'),
    (icone: 'carte', plein: 'carte-plein', nom: 'Carte'),
    (icone: 'profil', plein: 'profil-plein', nom: 'Profil'),
  ];

  static const _indexCreer = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: coquille,
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: Couleurs.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Couleurs.bord),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _onglets.length; i++)
                Expanded(
                  child: Appuyable(
                    semantique: _onglets[i].nom,
                    onTap: () => coquille.goBranch(i, initialLocation: i == coquille.currentIndex),
                    child: i == _indexCreer ? const _RondCreer() : _icone(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icone(int i) {
    final choisi = i == coquille.currentIndex;
    return Center(
      child: Icone(
        choisi ? _onglets[i].plein : _onglets[i].icone,
        taille: 26,
        couleur: choisi ? Couleurs.texte : Couleurs.discret,
      ),
    );
  }
}

class _RondCreer extends StatelessWidget {
  const _RondCreer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Couleurs.ocean, shape: BoxShape.circle),
        child: const Icone('plus', taille: 26, couleur: Colors.white),
      ),
    );
  }
}
