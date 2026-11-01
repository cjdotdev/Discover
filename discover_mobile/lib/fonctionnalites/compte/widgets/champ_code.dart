import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';

/// Le code à six chiffres : six cases dessinées, et un seul vrai champ, invisible, par-dessus.
class ChampCode extends StatefulWidget {
  const ChampCode({super.key, required this.surChangement, this.erreur = false});

  final ValueChanged<String> surChangement;
  final bool erreur;

  @override
  State<ChampCode> createState() => _ChampCodeState();
}

class _ChampCodeState extends State<ChampCode> {
  static const _longueur = 6;

  final _controleur = TextEditingController();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _controleur.text;
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < _longueur; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Case(chiffre: i < code.length ? code[i] : '', active: i == code.length, erreur: widget.erreur),
              ),
            ],
          ],
        ),
        Positioned.fill(
          child: Semantics(
            label: 'Code à six chiffres',
            child: TextField(
              controller: _controleur,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: _longueur,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              showCursor: false,
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
              onChanged: (valeur) {
                setState(() {});
                widget.surChangement(valeur);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({required this.chiffre, required this.active, required this.erreur});

  final String chiffre;
  final bool active;
  final bool erreur;

  @override
  Widget build(BuildContext context) {
    final bord = erreur ? Couleurs.erreur : (active ? Couleurs.ocean : Colors.transparent);
    return AnimatedContainer(
      duration: Durees.interface,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Mesures.rayonBouton),
        border: Border.all(color: bord, width: 1.6),
      ),
      child: Text(chiffre, style: Textes.sousTitre),
    );
  }
}
