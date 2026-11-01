import 'package:flutter/material.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/icone.dart';
import '../donnees/profil.dart';

/// E36, étape 3 : ce qu'on aime voir, trois au moins. Sert à ranger le fil d'accueil.
class EtapeGouts extends StatefulWidget {
  const EtapeGouts({super.key, required this.profil, required this.attente, required this.surFin});

  final Profil profil;
  final bool attente;
  final VoidCallback surFin;

  @override
  State<EtapeGouts> createState() => _EtapeGoutsState();
}

class _EtapeGoutsState extends State<EtapeGouts> {
  static const _minimum = 3;

  static const _themes = [
    (cle: 'mer', nom: 'Mer et plages'),
    (cle: 'cascades', nom: 'Cascades et rivières'),
    (cle: 'paysages', nom: 'Paysages'),
    (cle: 'nature', nom: 'Nature'),
    (cle: 'ville', nom: 'En ville'),
    (cle: 'architecture', nom: 'Architecture'),
    (cle: 'couchers', nom: 'Couchers de soleil'),
    (cle: 'culture', nom: 'Culture et patrimoine'),
    (cle: 'fetes', nom: 'Fêtes et musique'),
  ];

  Set<String> get _gouts => widget.profil.gouts;

  void _basculer(String cle) {
    setState(() {
      if (!_gouts.remove(cle)) _gouts.add(cle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _gouts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ce que vous aimez voir', style: Textes.titre),
        const SizedBox(height: 8),
        const Text('Choisissez au moins 3 types de lieux : votre fil commencera par eux.', style: Textes.discret),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: [
              for (final theme in _themes)
                _Tuile(
                  image: theme.cle,
                  nom: theme.nom,
                  choisie: _gouts.contains(theme.cle),
                  surAppui: () => _basculer(theme.cle),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Bouton(
          texte: nombre >= _minimum ? 'Terminer · $nombre choisis' : 'Encore ${_minimum - nombre}',
          chargement: widget.attente,
          onTap: nombre >= _minimum ? widget.surFin : null,
        ),
      ],
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({required this.image, required this.nom, required this.choisie, required this.surAppui});

  final String image;
  final String nom;
  final bool choisie;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    return Appuyable(
      semantique: nom,
      onTap: surAppui,
      child: AnimatedContainer(
        duration: Durees.interface,
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Mesures.rayonBouton),
          border: Border.all(color: choisie ? Couleurs.ocean : Colors.transparent, width: 2.5),
        ),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Mesures.rayonBouton)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/$image.webp', fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.42),
                padding: const EdgeInsets.all(6),
                child: Text(
                  nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Textes.petit.copyWith(color: Colors.white, height: 1.2, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (choisie)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Couleurs.ocean, shape: BoxShape.circle),
                  child: const Icone('coche', taille: 14, couleur: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
