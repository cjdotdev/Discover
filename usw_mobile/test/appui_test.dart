// Un bouton de verre ne doit jamais recreer ce qu il contient pendant l appui :
// son verre et sa lentille seraient detruits, et il clignoterait (ecran Aide).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usw/widgets/verre.dart';

int _naissances = 0;

class _Temoin extends StatefulWidget {
  const _Temoin();

  @override
  State<_Temoin> createState() => _TemoinState();
}

class _TemoinState extends State<_Temoin> {
  @override
  void initState() {
    super.initState();
    _naissances++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 160, height: 60);
}

void main() {
  for (final gonflement in [0.04, 0.12]) {
    testWidgets('le contenu survit a l appui et au rebond (gonflement $gonflement)', (tester) async {
      _naissances = 0;
      var touches = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Appuyable(verre: true, rayonVerre: 18, gonflement: gonflement, onTap: () => touches++, child: const _Temoin()),
          ),
        ),
      );
      expect(_naissances, 1);
      for (var i = 0; i < 3; i++) {
        final geste = await tester.startGesture(tester.getCenter(find.byType(_Temoin)));
        for (var f = 0; f < 6; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await geste.up();
        // Le relache et tout le rebond, image par image.
        for (var f = 0; f < 90; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      await tester.pumpAndSettle();
      expect(touches, 3);
      expect(_naissances, 1, reason: 'le contenu a ete recree pendant l appui');
    });
  }

  testWidgets('dans une case de grille, le bouton remplit la case', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 170,
            height: 66,
            child: Appuyable(
              verre: true,
              rayonVerre: 18,
              onTap: () {},
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ColoredBox).last), const Size(170, 66));
  });
}
