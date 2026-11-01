/// Une réponse d'erreur de l'API, toujours de la forme { "message", "erreurs" }.
class ErreurApi implements Exception {
  const ErreurApi(this.statut, this.message, [this.erreurs = const {}]);

  final int statut;
  final String message;

  /// Les erreurs de validation, champ par champ (statut 422).
  final Map<String, List<String>> erreurs;

  /// La première erreur d'un champ, sinon le message général.
  String pour(String champ) => erreurs[champ]?.first ?? message;
}

/// L'API ne répond pas : pas de réseau, ou serveur éteint.
class ApiInjoignable implements Exception {
  const ApiInjoignable();
}
