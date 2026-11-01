import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/champ.dart';
import '../../../socle/widgets/icone.dart';
import '../donnees/profil.dart';

/// E36, étape 1 : la photo, le nom affiché, le nom d'utilisateur et la bio.
class EtapeIdentite extends StatefulWidget {
  const EtapeIdentite({super.key, required this.profil, required this.surSuite});

  final Profil profil;
  final VoidCallback surSuite;

  @override
  State<EtapeIdentite> createState() => _EtapeIdentiteState();
}

class _EtapeIdentiteState extends State<EtapeIdentite> {
  static final _formeNom = RegExp(r'^[a-z0-9._]{3,30}$');

  late final _nomAffiche = TextEditingController(text: widget.profil.nomAffiche);
  late final _nomUtilisateur = TextEditingController(text: widget.profil.nomUtilisateur);
  late final _bio = TextEditingController(text: widget.profil.bio);
  String? _erreurNom;
  String? _erreurUtilisateur;

  @override
  void dispose() {
    _nomAffiche.dispose();
    _nomUtilisateur.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final octets = await image.readAsBytes();
    if (mounted) setState(() => widget.profil.photo = octets);
  }

  void _continuer() {
    final nom = _nomAffiche.text.trim();
    final utilisateur = _nomUtilisateur.text.trim();
    setState(() {
      _erreurNom = nom.isEmpty ? 'Indiquez votre nom.' : null;
      _erreurUtilisateur = _formeNom.hasMatch(utilisateur)
          ? null
          : '3 à 30 caractères : lettres minuscules, chiffres, . et _';
    });
    if (_erreurNom != null || _erreurUtilisateur != null) return;

    widget.profil
      ..nomAffiche = nom
      ..nomUtilisateur = utilisateur
      ..bio = _bio.text.trim();
    widget.surSuite();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.profil.photo;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Votre profil', style: Textes.titre),
          const SizedBox(height: 8),
          const Text('Ce que les autres verront à côté de vos photos.', style: Textes.discret),
          const SizedBox(height: 20),
          Center(
            child: Appuyable(
              semantique: 'Ajouter une photo',
              onTap: _choisirPhoto,
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Couleurs.ocean, shape: BoxShape.circle),
                    child: photo != null
                        ? Image.memory(photo, fit: BoxFit.cover, width: 88, height: 88)
                        : const Icone('camera', taille: 30, couleur: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text('Ajouter une photo', style: Textes.lien),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Champ(
            libelle: 'Nom affiché',
            icone: 'profil',
            indice: 'Votre nom',
            controleur: _nomAffiche,
            erreur: _erreurNom,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          Champ(
            libelle: "Nom d'utilisateur",
            icone: 'arobase',
            indice: 'votre.nom',
            controleur: _nomUtilisateur,
            erreur: _erreurUtilisateur,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          Champ(
            libelle: 'Bio (facultatif)',
            icone: 'plume',
            indice: 'Ce que vous aimez photographier',
            controleur: _bio,
            lignes: 2,
          ),
          const SizedBox(height: 18),
          Bouton(texte: 'Continuer', onTap: _continuer),
        ],
      ),
    );
  }
}
