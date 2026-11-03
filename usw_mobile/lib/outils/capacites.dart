// Ce que le telephone peut afficher sans peine : sa memoire et la plus grande image que sa
// carte graphique accepte (lus une fois, au lancement). Une image se decode entiere en
// memoire, 4 octets par pixel : une 4K fait 33 Mo, une 8K 133 Mo.
import 'dart:math' as math;

import 'appareil.dart';

class Capacites {
  Capacites._();
  static final instance = Capacites._();

  /// La memoire du telephone, en Mo.
  int memoireMo = 2048;

  /// Le plus grand cote d une image que la carte graphique accepte.
  int textureMax = 4096;

  /// Un telephone « petit » (Android Go) : on reste prudent.
  bool faible = false;

  Future<void> charger() async {
    final c = await Appareil.capacites();
    if (c == null) return;
    memoireMo = (c['memoireMo'] as num?)?.toInt() ?? memoireMo;
    textureMax = (c['textureMax'] as num?)?.toInt() ?? textureMax;
    faible = c['faible'] == true;
  }

  // Une seule image a l ecran ne prend pas plus d un seizieme de la memoire (un trente-deuxieme
  // sur un petit telephone) : 128 Mo sur un telephone de 2 Go, soit 32 Mpx.
  int get _octetsMax => memoireMo * 1024 * 1024 ~/ (faible ? 32 : 16);

  /// Une image de [largeur] x [hauteur] px s affiche-t-elle sans risque ?
  bool peutAfficher(int largeur, int hauteur) => math.max(largeur, hauteur) <= textureMax && largeur * hauteur * 4 <= _octetsMax;

  /// La plus grande taille a charger dans la visionneuse : la 4K si le telephone la porte.
  bool get porteLa4K => peutAfficher(3840, 2880);
}
