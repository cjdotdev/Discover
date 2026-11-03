import 'package:flutter_test/flutter_test.dart';
import 'package:usw/app.dart';

void main() {
  test('un lien partage ouvert dans l application mene a sa page', () {
    expect(lienPartage(Uri.parse('https://discover.simeonamoussou.com/l/ouidah')), '/accueil/lieu/ouidah');
    expect(lienPartage(Uri.parse('https://discover.simeonamoussou.com/@simeon')), '/accueil/createur/simeon');
    // Une publication passe par sa propre route (son lieu se lit sur le serveur) ; le reste ne bouge pas.
    expect(lienPartage(Uri.parse('/p/01JABC')), isNull);
    expect(lienPartage(Uri.parse('/accueil/lieu/ouidah')), isNull);
    expect(lienPartage(Uri.parse('/@')), isNull);
  });
}
