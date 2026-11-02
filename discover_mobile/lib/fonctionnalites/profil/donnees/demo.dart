// Les collections du profil de démonstration (repris de usw_mobile, donnees/demo.dart).
import '../../decouverte/donnees/demo.dart';

/// Une collection d enregistrements (E19), secrete ou non.
class Collection {
  const Collection({required this.nom, required this.refs, this.secrete = false, required this.nombre});

  final String nom;
  final List<RefPublication> refs;
  final bool secrete;
  final int nombre;
}

/// Les collections du compte ; « Créer une collection » en ajoute.
final collectionsDemo = <Collection>[
  const Collection(
    nom: 'Plages',
    secrete: true,
    nombre: 25,
    refs: [('grand-popo', 1), ('ouidah', 0), ('grand-popo', 3), ('aheme', 0), ('grand-popo', 6)],
  ),
  const Collection(nom: 'Cascades', nombre: 12, refs: [('kota', 0), ('kota', 1), ('atacora', 2), ('kota', 3)]),
  const Collection(nom: 'Week-end à Ouidah', nombre: 8, refs: [('ouidah', 2), ('ouidah', 4), ('porto-novo', 2)]),
  const Collection(
    nom: 'Idées de voyage',
    nombre: 31,
    refs: [('pendjari', 0), ('dassa', 0), ('atacora', 1), ('pendjari', 2)],
  ),
];
