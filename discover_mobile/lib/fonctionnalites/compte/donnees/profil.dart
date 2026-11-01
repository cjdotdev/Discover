import 'dart:typed_data';

/// Ce que le membre remplit à sa première connexion (E36).
class Profil {
  Uint8List? photo;
  String nomAffiche = '';
  String nomUtilisateur = '';
  String bio = '';
  String pays = 'Bénin';
  String ville = 'Cotonou';
  bool utiliserPosition = true;
  final Set<String> gouts = {};
}
