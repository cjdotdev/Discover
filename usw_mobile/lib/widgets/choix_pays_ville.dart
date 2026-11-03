// Le pays et la ville du profil (Completer le profil, Modifier le profil) :
// tous les pays du serveur (GET geo/pays), puis les villes du pays choisi
// (GET geo/pays/{code}/villes). Une feuille par choix, avec une recherche en haut.
// La ville qui n est pas dans la liste se saisit telle quelle.
import 'dart:async';

import 'package:flutter/material.dart';

import '../outils/api.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import 'champ.dart';
import 'feuille.dart';
import 'icone.dart';
import 'verre.dart';

/// Un pays : son code (BJ) et son nom en francais (Benin).
class Pays {
  const Pays(this.code, this.nom);

  final String code;
  final String nom;
}

/// Les pays et les villes, d apres le serveur. La liste des pays se charge une fois par lancement.
class Geo {
  Geo._();

  static List<Pays>? _pays;
  static Future<List<Pays>>? _enCours;

  /// Tous les pays, deja par ordre alphabetique. Hors ligne : ApiInjoignable.
  static Future<List<Pays>> pays() {
    final connus = _pays;
    if (connus != null) return Future.value(connus);
    return _enCours ??= _chargerPays().whenComplete(() {
      _enCours = null;
    });
  }

  static Future<List<Pays>> _chargerPays() async {
    final r = await Api.instance.get('geo/pays?langue=fr');
    final liste = [
      for (final p in (r.json['data'] as List? ?? const []).cast<Map>())
        if (p['code'] is String && p['nom'] is String) Pays(p['code'] as String, p['nom'] as String),
    ];
    if (liste.isNotEmpty) _pays = liste;
    return liste;
  }

  /// Le code d un pays d apres son nom (celui du profil, ou celui donne par la position).
  static String? codeDe(String nom, List<Pays> pays) {
    final cherche = plat(nom);
    if (cherche.isEmpty) return null;
    return pays.where((p) => plat(p.nom) == cherche).firstOrNull?.code;
  }

  /// Les villes d un pays : sans texte, les plus peuplees par ordre alphabetique ;
  /// avec un texte, celles qui commencent par lui.
  static Future<List<String>> villes(String code, [String texte = '']) async {
    final q = texte.trim();
    final r = await Api.instance.get('geo/pays/${Uri.encodeComponent(code)}/villes${q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}');
    final noms = <String>[];
    for (final v in (r.json['data'] as List? ?? const []).cast<Map>()) {
      final nom = v['nom'];
      if (nom is String && nom.isNotEmpty && !noms.contains(nom)) noms.add(nom);
    }
    return noms;
  }
}

/// Sans accents, majuscules ni ponctuation : « Côte d’Ivoire » = « cote d ivoire ».
String plat(String t) {
  const de = 'àâäáãåéèêëíìîïóòôöõúùûüçñýÿœæ';
  const vers = 'aaaaaaeeeeiiiiooooouuuucnyyoa';
  final b = StringBuffer();
  for (final c in t.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : vers[i]);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

// Le nom commence par le texte, ou un de ses mots.
bool _correspond(String nom, String cherche) {
  if (cherche.isEmpty) return true;
  final n = plat(nom);
  return n.startsWith(cherche) || n.split(' ').any((m) => m.startsWith(cherche));
}

/// Les deux champs Pays et Ville. Choisir un autre pays ouvre ensuite le choix de la ville.
class ChoixPaysVille extends StatelessWidget {
  const ChoixPaysVille({super.key, required this.pays, required this.ville, required this.onChanged});

  final String pays;
  final String ville;
  final void Function(String pays, String ville) onChanged;

  Future<void> _pays(BuildContext context) async {
    final nouveau = await montrerFeuille<String>(
      context,
      titre: t('Pays'),
      contenu: (_) => _FeuillePays(actuel: pays),
    );
    if (nouveau == null || nouveau == pays) return;
    onChanged(nouveau, '');
    if (!context.mounted) return;
    final v = await _choisirVille(context, nouveau, '');
    if (v != null) onChanged(nouveau, v);
  }

  Future<void> _ville(BuildContext context) async {
    final v = await _choisirVille(context, pays, ville);
    if (v != null && v != ville) onChanged(pays, v);
  }

  static Future<String?> _choisirVille(BuildContext context, String pays, String actuelle) => montrerFeuille<String>(
    context,
    titre: t('Ville'),
    contenu: (_) => _FeuilleVilles(pays: pays, actuelle: actuelle),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Selecteur(libelle: t('Pays'), icone: 'globe', valeur: pays, indice: t('Choisir un pays'), onTap: () => _pays(context)),
      const SizedBox(height: 16),
      _Selecteur(libelle: t('Ville'), icone: 'lieu', valeur: ville, indice: t('Choisir une ville'), onTap: () => _ville(context)),
    ],
  );
}

class _Selecteur extends StatelessWidget {
  const _Selecteur({required this.libelle, required this.icone, required this.valeur, required this.indice, required this.onTap});

  final String libelle;
  final String icone;
  final String valeur;
  final String indice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(libelle, style: Textes.libelle),
      const SizedBox(height: 8),
      Appuyable(
        onTap: onTap,
        semantique: t('{libelle} : {valeur}', {'libelle': libelle, 'valeur': valeur.isEmpty ? indice : valeur}),
        child: Verre(
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icone(icone, taille: 22, couleur: Couleurs.discret),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      valeur.isEmpty ? indice : valeur,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: valeur.isEmpty ? Couleurs.discret : Couleurs.texte),
                    ),
                  ),
                  Icone('chevron-bas', taille: 20, couleur: Couleurs.discret),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Le haut commun des deux feuilles : la recherche, puis la liste (ou l attente, ou l echec).
class _Cadre extends StatelessWidget {
  const _Cadre({required this.recherche, required this.indice, required this.onChanged, required this.corps});

  final TextEditingController recherche;
  final String indice;
  final ValueChanged<String> onChanged;
  final Widget corps;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ChampVerre(icone: 'loupe', indice: indice, controleur: recherche, action: TextInputAction.search, onChanged: onChanged),
      ),
      // Une hauteur fixe : la feuille ne saute pas pendant la saisie ; elle se reduit si le clavier prend la place.
      Flexible(
        child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.55, child: corps),
      ),
    ],
  );
}

Widget _attente() => const Center(child: LogoQuiTourne(taille: 34));

Widget _echec(String texte, VoidCallback reessayer) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(texte, style: Textes.discret, textAlign: TextAlign.center),
      const SizedBox(height: 10),
      BoutonVerre(texte: t('Réessayer'), large: false, onTap: reessayer),
    ],
  ),
);

Widget _ligne(BuildContext context, String nom, bool choisi) => ListTile(
  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  title: Text(nom, style: TextStyle(fontSize: 16, fontWeight: choisi ? FontWeight.w700 : FontWeight.w400)),
  trailing: choisi ? Icone('coche', couleur: Couleurs.texte) : null,
  onTap: () => Navigator.pop(context, nom),
);

class _FeuillePays extends StatefulWidget {
  const _FeuillePays({required this.actuel});

  final String actuel;

  @override
  State<_FeuillePays> createState() => _FeuillePaysState();
}

class _FeuillePaysState extends State<_FeuillePays> {
  final _recherche = TextEditingController();
  List<Pays>? _pays;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final liste = await Geo.pays();
      if (mounted) setState(() => _pays = liste);
    } on ApiInjoignable {
      if (mounted) setState(() => _erreur = t('Aucune connexion. Vérifiez le réseau, puis réessayez.'));
    } on ErreurApi catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cherche = plat(_recherche.text);
    final pays = [
      for (final p in _pays ?? const <Pays>[])
        if (_correspond(p.nom, cherche)) p,
    ];
    final Widget corps;
    if (_erreur != null) {
      corps = Align(alignment: Alignment.topCenter, child: _echec(_erreur!, _charger));
    } else if (_pays == null) {
      corps = _attente();
    } else if (pays.isEmpty) {
      corps = Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Text(t('Aucun pays ne correspond à « {texte} ».', {'texte': _recherche.text.trim()}), style: Textes.discret, textAlign: TextAlign.center),
      );
    } else {
      corps = ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), itemCount: pays.length, itemBuilder: (context, i) => _ligne(context, pays[i].nom, pays[i].nom == widget.actuel));
    }
    return _Cadre(recherche: _recherche, indice: t('Rechercher un pays'), onChanged: (_) => setState(() {}), corps: corps);
  }
}

class _FeuilleVilles extends StatefulWidget {
  const _FeuilleVilles({required this.pays, required this.actuelle});

  final String pays;
  final String actuelle;

  @override
  State<_FeuilleVilles> createState() => _FeuilleVillesState();
}

class _FeuilleVillesState extends State<_FeuilleVilles> {
  final _recherche = TextEditingController();
  Timer? _pause;

  // Le code du pays (nul : un pays que le serveur ne connait pas, la saisie libre seule).
  String? _code;
  bool _codeCherche = false;
  List<String>? _villes;
  String? _erreur;

  // Le texte de la derniere demande : une reponse plus ancienne est ignoree.
  String _demande = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _pause?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final texte = _recherche.text.trim();
    _demande = texte;
    setState(() {
      _erreur = null;
      _villes = null;
    });
    try {
      if (!_codeCherche) {
        _code = Geo.codeDe(widget.pays, await Geo.pays());
        _codeCherche = true;
      }
      final code = _code;
      final villes = code == null ? const <String>[] : await Geo.villes(code, texte);
      if (mounted && _demande == texte) setState(() => _villes = villes);
    } on ApiInjoignable {
      if (mounted && _demande == texte) setState(() => _erreur = t('Aucune connexion. Vérifiez le réseau, puis réessayez.'));
    } on ErreurApi catch (e) {
      if (mounted && _demande == texte) setState(() => _erreur = e.message);
    }
  }

  // Une courte pause dans la saisie, puis la demande au serveur.
  void _saisie(String _) {
    _pause?.cancel();
    setState(() {});
    _pause = Timer(const Duration(milliseconds: 300), _charger);
  }

  @override
  Widget build(BuildContext context) {
    final saisie = _recherche.text.trim();
    final villes = _villes;
    // La ville tapee qui n est pas dans la liste : on la garde telle quelle.
    final libre = saisie.isNotEmpty && !(villes ?? const <String>[]).any((v) => plat(v) == plat(saisie));
    final enAttente = _erreur == null && villes == null;
    final lignes = <Widget>[
      if (libre)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Icone('plus', taille: 22, couleur: Couleurs.texte),
          title: Text(t('Utiliser « {nom} »', {'nom': saisie}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          onTap: () => Navigator.pop(context, saisie),
        ),
      if (_erreur != null) _echec(_erreur!, _charger),
      if (villes != null && villes.isEmpty && saisie.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Text(t('Aucune ville connue pour ce pays. Saisissez son nom.'), style: Textes.discret, textAlign: TextAlign.center),
        ),
      for (final v in villes ?? const <String>[]) _ligne(context, v, v == widget.actuelle),
    ];
    final corps = enAttente && !libre
        ? _attente()
        : ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              ...lignes,
              if (enAttente)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(child: LogoQuiTourne(taille: 34)),
                ),
            ],
          );
    return _Cadre(recherche: _recherche, indice: t('Rechercher une ville'), onChanged: _saisie, corps: corps);
  }
}
