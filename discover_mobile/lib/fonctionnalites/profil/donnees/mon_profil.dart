import 'package:flutter/foundation.dart';

/// Le profil du membre connecté, celui du compte de démonstration (repris de la session
/// de usw_mobile). E18 le montre, E21 le modifie.
/// À brancher : GET moi et PATCH moi.
class MonProfil extends ChangeNotifier {
  MonProfil._();
  static final instance = MonProfil._();

  String nomAffiche = 'Akouavi K.';
  String nomUtilisateur = 'akouavi.k';
  String email = 'akouavi.k@gmail.com';
  String bio = 'Photos du golfe de Guinée, de Ouidah à Grand-Popo.';
  String site = 'akouavi.photo';
  String pays = 'Bénin';
  String ville = 'Cotonou';
  bool position = true;

  void enregistrer({
    required String nomAffiche,
    required String nomUtilisateur,
    required String bio,
    required String site,
  }) {
    this.nomAffiche = nomAffiche;
    this.nomUtilisateur = nomUtilisateur;
    this.bio = bio;
    this.site = site;
    notifyListeners();
  }
}
