import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/icone.dart';
import '../donnees/profil.dart';

/// E36, étape 2 : le pays, la ville, et l'accord pour utiliser la position.
class EtapeLieu extends StatefulWidget {
  const EtapeLieu({super.key, required this.profil, required this.surSuite});

  final Profil profil;
  final VoidCallback surSuite;

  @override
  State<EtapeLieu> createState() => _EtapeLieuState();
}

class _EtapeLieuState extends State<EtapeLieu> {
  // Une courte liste pour le MVP ; plus tard, elle viendra de l'API.
  static const _villes = {
    'Bénin': ['Abomey-Calavi', 'Cotonou', 'Ouidah', 'Parakou', 'Porto-Novo'],
    'Burkina Faso': ['Bobo-Dioulasso', 'Ouagadougou'],
    "Côte d'Ivoire": ['Abidjan', 'Bouaké', 'Yamoussoukro'],
    'Nigeria': ['Abuja', 'Ibadan', 'Lagos'],
    'Sénégal': ['Dakar', 'Saint-Louis'],
    'Togo': ['Kara', 'Lomé'],
  };

  Profil get _profil => widget.profil;

  void _choisirPays(String pays) {
    setState(() {
      _profil.pays = pays;
      _profil.ville = _villes[pays]!.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("D'où êtes-vous ?", style: Textes.titre),
          const SizedBox(height: 8),
          const Text("Pour vous montrer d'abord les lieux près de chez vous.", style: Textes.discret),
          const SizedBox(height: 22),
          _Liste(
            libelle: 'Pays',
            icone: 'globe',
            valeur: _profil.pays,
            choix: _villes.keys.toList(),
            surChoix: _choisirPays,
          ),
          const SizedBox(height: 16),
          _Liste(
            libelle: 'Ville',
            icone: 'lieu',
            valeur: _profil.ville,
            choix: _villes[_profil.pays]!,
            surChoix: (ville) => setState(() => _profil.ville = ville),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(Mesures.rayonCarte),
            ),
            child: Row(
              children: [
                const Icone('cible', couleur: Couleurs.texte),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Utiliser ma position', style: Textes.libelle),
                      SizedBox(height: 2),
                      Text(
                        'Pour le fil « Près de moi ». Modifiable à tout moment dans les réglages.',
                        style: Textes.petit,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _profil.utiliserPosition,
                  activeTrackColor: Couleurs.ocean,
                  onChanged: (valeur) => setState(() => _profil.utiliserPosition = valeur),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Bouton(texte: 'Continuer', onTap: widget.surSuite),
        ],
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.libelle,
    required this.icone,
    required this.valeur,
    required this.choix,
    required this.surChoix,
  });

  final String libelle;
  final String icone;
  final String valeur;
  final List<String> choix;
  final ValueChanged<String> surChoix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(libelle, style: Textes.libelle),
        const SizedBox(height: 8),
        Container(
          height: Mesures.hautChamp,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(Mesures.rayonBouton),
          ),
          child: Row(
            children: [
              Icone(icone, taille: 20, couleur: Couleurs.discret),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  value: valeur,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  icon: const Icone('chevron-bas', taille: 20, couleur: Couleurs.discret),
                  style: Textes.corps,
                  dropdownColor: Couleurs.surface,
                  borderRadius: BorderRadius.circular(Mesures.rayonBouton),
                  items: [for (final nom in choix) DropdownMenuItem(value: nom, child: Text(nom))],
                  onChanged: (nom) {
                    if (nom != null) surChoix(nom);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
