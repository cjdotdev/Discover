import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/mesures.dart';
import '../theme/textes.dart';
import 'icone.dart';

/// Un champ de formulaire : libellé au-dessus, icône à gauche, bord océan quand il a le curseur,
/// erreur en dessous. `secret` ajoute l'œil qui montre le mot de passe.
class Champ extends StatefulWidget {
  const Champ({
    super.key,
    required this.icone,
    required this.indice,
    this.libelle,
    this.controleur,
    this.erreur,
    this.secret = false,
    this.clavier,
    this.action,
    this.autofocus = false,
    this.lignes = 1,
    this.surChangement,
    this.surValidation,
  });

  final String icone;
  final String indice;
  final String? libelle;
  final TextEditingController? controleur;
  final String? erreur;
  final bool secret;
  final TextInputType? clavier;
  final TextInputAction? action;
  final bool autofocus;
  final int lignes;
  final ValueChanged<String>? surChangement;
  final ValueChanged<String>? surValidation;

  @override
  State<Champ> createState() => _ChampState();
}

class _ChampState extends State<Champ> {
  final _focus = FocusNode();
  bool _cache = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enErreur = widget.erreur != null;
    final couleurBord = enErreur ? Couleurs.erreur : (_focus.hasFocus ? Couleurs.ocean : Colors.transparent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.libelle != null) ...[Text(widget.libelle!, style: Textes.libelle), const SizedBox(height: 8)],
        AnimatedContainer(
          duration: Durees.interface,
          constraints: const BoxConstraints(minHeight: Mesures.hautChamp),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(Mesures.rayonBouton),
            border: Border.all(color: couleurBord, width: 1.6),
          ),
          child: Row(
            children: [
              Icone(widget.icone, taille: 20, couleur: Couleurs.discret),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controleur,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  obscureText: widget.secret && _cache,
                  keyboardType: widget.clavier,
                  textInputAction: widget.action,
                  minLines: widget.lignes,
                  maxLines: widget.lignes,
                  onChanged: widget.surChangement,
                  onSubmitted: widget.surValidation,
                  style: Textes.corps,
                  decoration: InputDecoration(
                    hintText: widget.indice,
                    hintStyle: Textes.corps.copyWith(color: Couleurs.discret),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              if (widget.secret)
                Semantics(
                  button: true,
                  label: _cache ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                  child: GestureDetector(
                    onTap: () => setState(() => _cache = !_cache),
                    child: Icone(_cache ? 'oeil' : 'oeil-barre', taille: 20, couleur: Couleurs.discret),
                  ),
                ),
            ],
          ),
        ),
        if (enErreur) ...[
          const SizedBox(height: 6),
          Text(widget.erreur!, style: Textes.petit.copyWith(color: Couleurs.erreur)),
        ],
      ],
    );
  }
}
