// La vitrine de la bienvenue et de l entree : deux photos voisines ne viennent pas du meme
// lieu, et une photo ne revient pas a cote d elle-meme.
import 'package:flutter_test/flutter_test.dart';
import 'package:usw/donnees/catalogue.dart';

void main() {
  // Comme le serveur aujourd hui : 20 photos sur 7 lieux (4, 4, 4, 3, 2, 2, 1).
  final candidats = [
    for (final (lieu, n) in [('ifri', 4), ('zone', 4), ('fidjrosse', 4), ('plage', 3), ('calavi', 2), ('uac', 2), ('sans', 1)])
      for (var i = 0; i < n; i++) (photo: '$lieu-$i', lieu: lieu),
  ];
  String lieu(String photo) => photo.split('-').first;

  test('la pile de la bienvenue : six photos de six lieux', () {
    final photos = disposerVitrine(candidats, 6, 1);
    expect(photos.map(lieu).toSet(), hasLength(6));
  });

  test('la mosaique de l entree : ni le meme lieu ni la meme photo a cote', () {
    const colonnes = 3, lignes = 5;
    final photos = disposerVitrine(candidats, colonnes * lignes, colonnes);
    expect(photos.toSet(), hasLength(colonnes * lignes), reason: 'assez de photos : aucune ne revient');
    String a(int c, int l) => photos[c * lignes + l];
    for (var c = 0; c < colonnes; c++) {
      for (var l = 0; l < lignes; l++) {
        // L une sous l autre, et le bas contre le haut (la colonne reboucle).
        expect(lieu(a(c, l)), isNot(lieu(a(c, (l + 1) % lignes))), reason: 'colonne $c, lignes $l et ${(l + 1) % lignes}');
        // Cote a cote et en diagonale.
        if (c + 1 < colonnes) {
          for (final d in [-1, 0, 1]) {
            if (l + d < 0 || l + d >= lignes) continue;
            expect(lieu(a(c, l)), isNot(lieu(a(c + 1, l + d))), reason: 'colonnes $c et ${c + 1}, lignes $l et ${l + d}');
          }
        }
      }
    }
  });

  test('peu de photos : une photo ne revient jamais a cote d elle-meme', () {
    final peu = candidats.take(6).toList();
    const colonnes = 3, lignes = 5;
    final photos = disposerVitrine(peu, colonnes * lignes, colonnes);
    String a(int c, int l) => photos[c * lignes + l];
    for (var c = 0; c < colonnes; c++) {
      for (var l = 0; l < lignes; l++) {
        expect(a(c, l), isNot(a(c, (l + 1) % lignes)));
        if (c + 1 < colonnes) {
          for (final d in [-1, 0, 1]) {
            if (l + d >= 0 && l + d < lignes) expect(a(c, l), isNot(a(c + 1, l + d)));
          }
        }
      }
    }
  });

  test('rien de recu : des cases vides', () {
    expect(disposerVitrine([], 4, 1), ['', '', '', '']);
  });
}
