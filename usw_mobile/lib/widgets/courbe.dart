// Les graphiques de « Gérer Discover », sobres : une mesure par courbe (son
// titre la nomme, pas de legende), une seule teinte (l ocean), un trait de
// 2 px, une grille discrete. Le doigt pose sur la courbe montre le jour et
// sa valeur. Les classements sont des barres ; l activite d un membre, une
// bande de 30 jours.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../outils/langue.dart';
import '../theme/jetons.dart';

// Les mois en court, dans la langue choisie (lus a chaque appel).
String _mois(int m) => switch (m) {
  1 => t('janv.'),
  2 => t('févr.'),
  3 => t('mars'),
  4 => t('avr.'),
  5 => t('mai'),
  6 => t('juin'),
  7 => t('juil.'),
  8 => t('août'),
  9 => t('sept.'),
  10 => t('oct.'),
  11 => t('nov.'),
  _ => t('déc.'),
};

String jourCourt(DateTime d) => t('{jour} {mois}', {'jour': d.day, 'mois': _mois(d.month)});

/// Un nombre lisible : 1 234, 12,5 k.
String nombreLisible(int n) {
  if (n < 10000) return n < 1000 ? '$n' : '${n ~/ 1000} ${(n % 1000).toString().padLeft(3, '0')}';
  final k = n / 1000;
  return t('{n} k', {'n': k.toStringAsFixed(k < 100 ? 1 : 0).replaceAll('.', ',')});
}

/// Une courbe d une mesure par jour, son total, et la lecture au doigt.
class Courbe extends StatefulWidget {
  const Courbe({super.key, required this.titre, required this.valeurs, required this.dates, this.hauteur = 120, this.resume});

  final String titre;
  final List<int> valeurs;
  final List<DateTime> dates;
  final double hauteur;

  /// Ce qui s ecrit a droite du titre (le total, une moyenne) ; par defaut, le total.
  final String? resume;

  @override
  State<Courbe> createState() => _CourbeState();
}

class _CourbeState extends State<Courbe> {
  int? _lu;

  void _lire(Offset p, double largeur) {
    final n = widget.valeurs.length;
    if (n == 0 || largeur <= 0) return;
    final i = ((p.dx / largeur) * (n - 1)).round().clamp(0, n - 1);
    if (i != _lu) setState(() => _lu = i);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.valeurs;
    final total = v.fold<int>(0, (a, b) => a + b);
    final lu = _lu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.titre,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Couleurs.texte),
              ),
            ),
            // Le doigt sur la courbe : le jour et sa valeur ; sinon, le total.
            Text(
              lu == null ? (widget.resume ?? nombreLisible(total)) : '${jourCourt(widget.dates[lu])} · ${nombreLisible(v[lu])}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Couleurs.texte, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _lire(d.localPosition, c.maxWidth),
            onHorizontalDragStart: (d) => _lire(d.localPosition, c.maxWidth),
            onHorizontalDragUpdate: (d) => _lire(d.localPosition, c.maxWidth),
            onHorizontalDragEnd: (_) => setState(() => _lu = null),
            onTapUp: (_) => Future<void>.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _lu = null) : null),
            child: Semantics(
              label: t('{titre} : {total} sur {jours} jours', {'titre': widget.titre, 'total': total, 'jours': v.length}),
              child: SizedBox(
                height: widget.hauteur,
                width: c.maxWidth,
                child: CustomPaint(
                  painter: _PeintreCourbe(valeurs: v, lu: lu, trait: Couleurs.ocean, fond: Couleurs.surface, grille: Couleurs.filet, texte: Couleurs.discret),
                ),
              ),
            ),
          ),
        ),
        if (widget.dates.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(jourCourt(widget.dates.first), style: TextStyle(fontSize: 11.5, color: Couleurs.discret)),
              Text(jourCourt(widget.dates.last), style: TextStyle(fontSize: 11.5, color: Couleurs.discret)),
            ],
          ),
        ],
      ],
    );
  }
}

class _PeintreCourbe extends CustomPainter {
  _PeintreCourbe({required this.valeurs, required this.lu, required this.trait, required this.fond, required this.grille, required this.texte});

  final List<int> valeurs;
  final int? lu;
  final Color trait, fond, grille, texte;

  @override
  void paint(Canvas canvas, Size s) {
    final n = valeurs.length;
    final haut = math.max(1, valeurs.fold<int>(0, math.max));
    // Une grille discrete : la base et le maximum, nomme a gauche.
    final ligne = Paint()
      ..color = grille
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, s.height - 0.5), Offset(s.width, s.height - 0.5), ligne);
    canvas.drawLine(const Offset(0, 0.5), Offset(s.width, 0.5), ligne);
    final max = TextPainter(
      text: TextSpan(
        text: nombreLisible(haut),
        style: TextStyle(fontSize: 10.5, color: texte),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    max.paint(canvas, const Offset(0, 3));
    if (n == 0) return;

    Offset point(int i) => Offset(n == 1 ? s.width / 2 : s.width * i / (n - 1), s.height - (valeurs[i] / haut) * (s.height - 16) - 1);
    final chemin = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < n; i++) {
      chemin.lineTo(point(i).dx, point(i).dy);
    }
    // Une aire tres legere sous le trait, de la meme teinte.
    final aire = Path.from(chemin)
      ..lineTo(point(n - 1).dx, s.height)
      ..lineTo(point(0).dx, s.height)
      ..close();
    canvas.drawPath(aire, Paint()..color = trait.withValues(alpha: 0.1));
    canvas.drawPath(
      chemin,
      Paint()
        ..color = trait
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final i = lu;
    if (i != null) {
      final p = point(i);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, s.height),
        Paint()
          ..color = texte.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      // Le point lu : 8 px, cercle de 2 px de la couleur du fond.
      canvas.drawCircle(p, 6, Paint()..color = fond);
      canvas.drawCircle(p, 4, Paint()..color = trait);
    }
  }

  @override
  bool shouldRepaint(_PeintreCourbe a) => a.valeurs != valeurs || a.lu != lu || a.trait != trait || a.fond != fond;
}

/// Un classement : le nom, une barre proportionnelle, la valeur.
class Classement extends StatelessWidget {
  const Classement({super.key, required this.lignes, this.onTap});

  final List<(String, int)> lignes;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final haut = math.max(1, lignes.fold<int>(0, (a, l) => math.max(a, l.$2)));
    return Column(
      children: [
        for (var i = 0; i < lignes.length; i++)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(i),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      lignes[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: Couleurs.texte),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: math.max(4, c.maxWidth * lignes[i].$2 / haut),
                          height: 8,
                          decoration: BoxDecoration(
                            color: Couleurs.ocean,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    nombreLisible(lignes[i].$2),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Couleurs.texte, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// L activite d un membre : un carre par jour, plein les jours ou il est venu.
class BandeJours extends StatelessWidget {
  const BandeJours({super.key, required this.actif, required this.dates});

  final List<int> actif;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final n = actif.where((v) => v > 0).length;
    return Semantics(
      label: t('Actif {n} jours sur {total}', {'n': n, 'total': actif.length}),
      child: Row(
        children: [
          for (var i = 0; i < actif.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: Tooltip(
                message: jourCourt(dates[i]),
                child: AspectRatio(
                  aspectRatio: 0.6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: actif[i] > 0 ? Couleurs.ocean : Couleurs.filet, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
