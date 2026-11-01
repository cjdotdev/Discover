/// Les règles d'un mot de passe, partagées par E02 (créer, nouveau) : huit caractères, un chiffre, une lettre.
abstract final class ReglesMotDePasse {
  static bool assezLong(String mot) => mot.length >= 8;
  static bool aUnChiffre(String mot) => mot.contains(RegExp(r'\d'));
  static bool aUneLettre(String mot) => mot.contains(RegExp(r'[a-zA-ZÀ-ÿ]'));

  static bool valide(String mot) => assezLong(mot) && aUnChiffre(mot) && aUneLettre(mot);
}
