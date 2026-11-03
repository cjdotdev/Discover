// E31 Recherche (et E04 Filtres) : une recherche libre (un lieu, une region,
// un type de lieu) et, a cote du champ, les filtres qui etaient sur
// l accueil : pays, types de lieux, distance, tri, captures verifiees. Sans
// texte : les recherches recentes, des idees de voyage (les types de lieux
// presents) et les lieux populaires. Sans resultat (E37) : une suggestion et
// d autres lieux. Le serveur cherche aussi
// (GET /api/v1/recherche?q=…, accents et majuscules ignores) : des lieux que
// le telephone n a pas encore vus, et des createurs.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../outils/chemins.dart';
import '../donnees/modeles.dart';
import '../donnees/capture.dart';
import '../donnees/catalogue.dart';
import '../donnees/lieux_enregistres.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/banniere.dart';
import '../widgets/feuille.dart';
import '../widgets/icone.dart';
import '../widgets/mosaique.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';

/// Les filtres retenus : ils restent d une recherche a l autre, et la carte les suit.
class Filtres {
  Filtres._();
  static final instance = Filtres._();

  /// Nul : tous les pays.
  String? pays;
  final types = <String>{};
  int? distanceKm;
  bool verifiees = false;

  /// Une cle (« Pertinence », « Près de moi », « Les plus publiés ») : traduite a l affichage.
  String tri = 'Pertinence';

  /// Ma position, demandee au choix d une distance ou de « Près de moi » (nulle : pas encore).
  ({double latitude, double longitude})? position;

  int get actifs => (pays != null ? 1 : 0) + types.length + (distanceKm != null ? 1 : 0) + (verifiees ? 1 : 0) + (tri != 'Pertinence' ? 1 : 0);

  void effacer() {
    pays = null;
    types.clear();
    distanceKm = null;
    verifiees = false;
    tri = 'Pertinence';
  }

  /// La distance d un lieu : celle du catalogue, sinon depuis la position demandee ici.
  int? km(Lieu l) {
    if (l.distanceKm != null) return l.distanceKm;
    final p = position;
    if (p == null || !l.situe) return null;
    return _distanceKm(p.latitude, p.longitude, l.latitude, l.longitude).round();
  }

  /// Une position pour les distances : le catalogue la connait deja, ou on la demande.
  Future<bool> trouverPosition() async {
    if (position != null || Catalogue.instance.lieux.any((l) => l.distanceKm != null)) return true;
    final p = await positionActuelle();
    if (p == null) return false;
    position = (latitude: p.latitude, longitude: p.longitude);
    return true;
  }

  /// Un lieu a au moins une capture verifiee (sa pile, puis toutes ses publications).
  // Le serveur dit combien de publications du lieu sont vérifiées ; sinon, celles déjà reçues.
  bool verifie(Lieu l) => l.nombreVerifiees != null ? l.nombreVerifiees! > 0 : Catalogue.instance.publicationsDe(l).any((p) => p.verifiee);

  /// Les lieux qui passent les filtres (pays, types, distance, captures verifiees).
  List<Lieu> appliquer(Iterable<Lieu> lieux) => [
    for (final l in lieux)
      if ((pays == null || l.pays == pays) && (types.isEmpty || types.contains(l.type)) && (distanceKm == null || (km(l) ?? 99999) <= distanceKm!) && (!verifiees || verifie(l))) l,
  ];
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * 6371.0088 * math.asin(math.min(1.0, math.sqrt(a.toDouble())));
}

/// Les types de lieux presents dans ce que le serveur a envoye (sans « Autres »),
/// dans l ordre de [typesDeLieux].
List<String> typesPresents() {
  final vus = {
    for (final l in Catalogue.instance.lieux)
      if (l.type.isNotEmpty && l.type != 'Autres') l.type,
  };
  return [...typesDeLieux.where(vus.contains), ...vus.where((t) => !typesDeLieux.contains(t))];
}

/// Les recherches de cette session, les plus recentes d abord.
final _recentes = <String>[];

/// Sans accents ni majuscules : « Ouidah » se trouve en tapant « ouidah ».
String texteSimple(String t) {
  const accents = {'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'à': 'a', 'â': 'a', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ç': 'c'};
  return t.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

class EcranRecherche extends StatefulWidget {
  const EcranRecherche({super.key});

  @override
  State<EcranRecherche> createState() => _EcranRechercheState();
}

class _EcranRechercheState extends State<EcranRecherche> {
  final _texte = TextEditingController();
  final f = Filtres.instance;

  // Une pile ou une liste de publications arrivee (captures verifiees) : les resultats suivent.
  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Catalogue.instance.addListener(_maj);
  }

  /// Ce que le serveur a trouve pour [_cherche] (nul : pas encore, ou hors ligne).
  ({List<Lieu> lieux, List<Createur> createurs, List<Publication> publications})? _serveur;
  String _cherche = '';
  Timer? _attente;

  @override
  void dispose() {
    Catalogue.instance.removeListener(_maj);
    _attente?.cancel();
    _texte.dispose();
    super.dispose();
  }

  // On laisse finir la frappe (300 ms) avant de demander au serveur.
  void _change() {
    setState(() {});
    _attente?.cancel();
    final q = _requete;
    if (q.isEmpty) {
      setState(() => _serveur = null);
      return;
    }
    _attente = Timer(const Duration(milliseconds: 300), () async {
      final r = await Catalogue.instance.chercher(q);
      if (!mounted || _requete != q) return;
      setState(() {
        _serveur = r;
        _cherche = q;
      });
    });
  }

  /// Les createurs trouves par le serveur.
  List<Createur> get _createurs {
    if (_requete.isEmpty) return const [];
    final s = _serveur;
    if (s != null && _cherche == _requete) return s.createurs;
    return const [];
  }

  String get _requete => _texte.text.trim();

  /// Les publications trouvees par le serveur (legende, titre ou lieu).
  List<Publication> get _publications {
    final s = _serveur;
    if (_requete.isEmpty || s == null || _cherche != _requete) return const [];
    return f.verifiees ? s.publications.where((p) => p.verifiee).toList() : s.publications;
  }

  List<Lieu> get _resultats {
    final mots = texteSimple(_requete).split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    final trouves = _serveur != null && _cherche == _requete ? _serveur!.lieux : const <Lieu>[];
    final ids = <String>{};
    final resultat = f.appliquer(
      [
        ...Catalogue.instance.lieux.where((l) {
          final champ = texteSimple('${l.nom} ${l.region} ${l.type} ${typeLisible(l.type)}');
          return mots.every(champ.contains);
        }),
        // Ce que le serveur connait en plus (des lieux pas encore passes par l accueil).
        ...trouves,
      ].where((l) => ids.add(l.id)),
    );
    if (f.tri == 'Près de moi') resultat.sort((a, b) => (f.km(a) ?? 99999).compareTo(f.km(b) ?? 99999));
    if (f.tri == 'Les plus publiés') resultat.sort((a, b) => b.nombre.compareTo(a.nombre));
    return resultat;
  }

  // Une suggestion quand rien ne correspond : un lieu dont un mot commence pareil.
  Lieu? get _suggestion {
    final debut = texteSimple(_requete).split(' ').first;
    if (debut.length < 3) return null;
    return Catalogue.instance.lieux.where((l) => texteSimple(l.nom).split(' ').any((m) => m.startsWith(debut.substring(0, 3)))).firstOrNull;
  }

  void _chercher(String t) {
    _texte.text = t;
    _texte.selection = TextSelection.collapsed(offset: t.length);
    _change();
  }

  void _voirType(String type) => setState(() {
    f.types
      ..clear()
      ..add(type);
    _texte.clear();
  });

  Future<void> _filtres() async {
    await ouvrirFiltres(context, onChange: () => setState(() {}), nombre: () => _resultats.length);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final cherche = _requete.isNotEmpty || f.actifs > 0;
    final resultats = cherche ? _resultats : const <Lieu>[];
    final createurs = _createurs;
    final publications = _publications;
    final idees = [for (final type in typesPresents()) (titre: typeLisible(type), photo: Catalogue.instance.photoDuType(type), onTap: () => _voirType(type))];
    // Les premiers lieux de Decouverte : le serveur les range deja du plus apprecie au moins apprecie.
    final populaires = [
      for (final l in Catalogue.instance.lieux.where((l) => l.photos.isNotEmpty).take(6)) (titre: l.nom, photo: l.photos.first, onTap: () => context.push(ici(context, 'lieu/${l.id}'))),
    ];
    final autres = Catalogue.instance.lieux.where((l) => l.photos.isNotEmpty).take(4).toList();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 6, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Row(
            children: [
              RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/accueil')),
              const SizedBox(width: 8),
              Expanded(
                child: Verre(
                  rayon: 25,
                  child: SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icone('loupe', taille: 21, couleur: Couleurs.discret),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _texte,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => _change(),
                            onSubmitted: (t) {
                              if (t.trim().isNotEmpty && !_recentes.contains(t.trim())) _recentes.insert(0, t.trim());
                            },
                            style: TextStyle(fontSize: 16, color: Couleurs.texte),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: t('Un lieu, un créateur, une envie'),
                              hintStyle: TextStyle(fontSize: 15, color: Couleurs.discret, fontWeight: FontWeight.w300),
                            ),
                          ),
                        ),
                        if (_texte.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _texte.clear();
                              _change();
                            },
                            child: Semantics(
                              button: true,
                              label: t('Effacer'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icone('fermer', taille: 18, couleur: Couleurs.discret),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RondVerre(icone: 'filtres', semantique: t('Filtres'), point: f.actifs > 0, onTap: _filtres),
            ],
          ),
          const SizedBox(height: 16),
          if (!cherche) ...[
            // La vie des membres : leurs lifestyles visibles.
            Plaque(
              child: LigneFeuille(icone: 'image', texte: t('Lifestyle'), onTap: () => context.push(ici(context, 'lifestyles'))),
            ),
            const SizedBox(height: 16),
            if (_recentes.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final r in _recentes.take(6)) Pastille(texte: r, icone: 'horloge', onTap: () => _chercher(r))],
              ),
              const SizedBox(height: 24),
            ],
            if (idees.isNotEmpty) ...[_TitreSection(t('Des idées de voyage')), _Idees(tuiles: idees), const SizedBox(height: 10)],
            if (populaires.isNotEmpty) ...[_TitreSection(t('Populaire sur Discover')), _Idees(tuiles: populaires)],
          ] else if (resultats.isEmpty && createurs.isEmpty && publications.isEmpty) ...[
            const SizedBox(height: 18),
            Icone('loupe', taille: 40, couleur: Couleurs.discret),
            const SizedBox(height: 12),
            Text(_requete.isEmpty ? t('Aucun lieu ne correspond à ces filtres') : t('Aucun résultat pour « {requete} »', {'requete': _requete}), style: Textes.sousTitre, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (_suggestion case final s?)
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  // Une seule phrase a traduire, le lieu propose au milieu.
                  for (final (i, morceau) in t('Vouliez-vous dire {lieu} ?').split('{lieu}').indexed) ...[
                    if (i > 0)
                      GestureDetector(
                        onTap: () => _chercher(s.nom),
                        child: Text(
                          s.nom,
                          style: Textes.discret.copyWith(color: Couleurs.texte, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                        ),
                      ),
                    if (morceau.isNotEmpty) Text(morceau, style: Textes.discret),
                  ],
                ],
              )
            else
              Text(t('Essayez un mot plus court, ou retirez un filtre.'), style: Textes.discret, textAlign: TextAlign.center),
            if (autres.isNotEmpty) ...[const SizedBox(height: 26), _TitreSection(t('D’autres lieux à découvrir')), _Lieux(lieux: autres, presDeMoi: false)],
          ] else ...[
            if (createurs.isNotEmpty) ...[_TitreSection(t('Créateurs')), for (final c in createurs.take(5)) _LigneCreateur(createur: c), const SizedBox(height: 14)],
            if (resultats.isNotEmpty)
              Text(
                f.types.isEmpty ? tn(resultats.length, '{n} lieu', '{n} lieux') : '${tn(resultats.length, '{n} lieu', '{n} lieux')} · ${f.types.map(typeLisible).join(', ')}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.discret),
              ),
            const SizedBox(height: 10),
            _Lieux(lieux: resultats, presDeMoi: f.tri == 'Près de moi'),
            if (publications.isNotEmpty) ...[
              const SizedBox(height: 14),
              _TitreSection(t('Publications')),
              MosaiquePublications(
                publications: publications,
                titre: (i) => publications[i].lieuNom ?? publications[i].auteur,
                onTap: (i) => context.push(ici(context, 'lieu/${publications[i].lieu ?? '_'}/photo/${publications[i].id}')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      header: true,
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      ),
    ),
  );
}

/// Les idees et les lieux populaires : des tuiles de photo assombries, le nom au milieu.
class _Idees extends StatelessWidget {
  const _Idees({required this.tuiles});

  final List<({String titre, String photo, VoidCallback onTap})> tuiles;

  @override
  Widget build(BuildContext context) {
    final colonnes = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
    return GridView.count(
      crossAxisCount: colonnes,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: colonnes == 3 ? 2 : 1.85,
      padding: const EdgeInsets.only(bottom: 14),
      children: [
        for (final (:titre, :photo, :onTap) in tuiles)
          Appuyable(
            semantique: titre,
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Photo(photo),
                  ColoredBox(color: Couleurs.hsl(229, 40, 8, 0.38)),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        titre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Un createur trouve : sa photo, son nom, son pseudo et ce qu il a publie.
class _LigneCreateur extends StatelessWidget {
  const _LigneCreateur({required this.createur});

  final Createur createur;

  @override
  Widget build(BuildContext context) => Appuyable(
    semantique: createur.nom,
    onTap: () => context.push(ici(context, 'createur/${createur.pseudo}')),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Avatar(nom: createur.nom, taille: 44, photo: createur.avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(createur.nom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('@${createur.pseudo}${(createur.nombre ?? 0) > 0 ? ' · ${nombrePublications(createur.nombre!)}' : ''}', style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
              ],
            ),
          ),
          Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
        ],
      ),
    ),
  );
}

/// Les lieux trouves, en mosaique plate facon Pinterest.
class _Lieux extends StatelessWidget {
  const _Lieux({required this.lieux, required this.presDeMoi});

  final List<Lieu> lieux;
  final bool presDeMoi;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var c = 0; c < 2; c++) ...[
        if (c > 0) const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              for (var i = c; i < lieux.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Appuyable(
                    semantique: lieux[i].nom,
                    onTap: () => context.push(ici(context, 'lieu/${lieux[i].id}')),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(aspectRatio: lieux[i].ratio, child: PhotoArrondie(lieux[i].photos.first, rayon: 12)),
                        const SizedBox(height: 6),
                        Text(lieux[i].nom, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25)),
                        Text(switch (presDeMoi ? Filtres.instance.km(lieux[i]) : null) {
                          final km? => '${t('À {km} km', {'km': km})} · ${nombrePublications(lieux[i].nombre)}',
                          _ => nombrePublications(lieux[i].nombre),
                        }, style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}

/// La feuille des filtres (E04), de la recherche comme de la carte : elle s ouvre tout de suite.
/// `nombre` : combien de lieux l ecran montrera avec ces filtres.
Future<void> ouvrirFiltres(BuildContext context, {VoidCallback? onChange, int Function()? nombre}) => montrerFeuille<void>(
  context,
  titre: t('Filtres'),
  contenu: (context) => _FeuilleFiltres(onChange: onChange ?? () {}, nombre: nombre ?? () => Filtres.instance.appliquer(Catalogue.instance.lieux).length),
);

class _FeuilleFiltres extends StatefulWidget {
  const _FeuilleFiltres({required this.onChange, required this.nombre});

  final VoidCallback onChange;
  final int Function() nombre;

  @override
  State<_FeuilleFiltres> createState() => _FeuilleFiltresState();
}

class _FeuilleFiltresState extends State<_FeuilleFiltres> {
  final f = Filtres.instance;

  void _changer(VoidCallback c) {
    setState(c);
    widget.onChange();
  }

  // Une distance ou « Près de moi » demande ma position ; sans elle, le choix d avant revient.
  Future<void> _avecPosition(VoidCallback choix, VoidCallback avant) async {
    _changer(choix);
    if (await f.trouverPosition()) {
      if (mounted) _changer(() {});
      return;
    }
    if (!mounted) return;
    _changer(avant);
    bulle(
      context,
      positionManquee == SansPosition.introuvable
          ? t('Impossible de trouver votre position pour le moment. Réessayez dans quelques secondes.')
          : t('Activez la position pour trier ou filtrer par distance.'),
      icone: 'cible',
    );
  }

  Widget _groupe(String titre, List<Widget> pastilles) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: pastilles),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final types = {...typesPresents(), ...f.types}.toList();
    final pays = {
      for (final l in Catalogue.instance.lieux)
        if ((l.pays ?? '').isNotEmpty) l.pays!,
      ?f.pays,
    }.toList()..sort();
    final nombre = widget.nombre();
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        if (pays.isNotEmpty)
          _groupe(t('Pays'), [
            Pastille(texte: t('Tous'), retenue: f.pays == null, onTap: () => _changer(() => f.pays = null)),
            for (final p in pays) Pastille(texte: p, retenue: f.pays == p, onTap: () => _changer(() => f.pays = p)),
          ]),
        if (types.isNotEmpty)
          _groupe(t('Types de lieux'), [
            for (final type in types)
              Pastille(texte: typeLisible(type), retenue: f.types.contains(type), onTap: () => _changer(() => f.types.contains(type) ? f.types.remove(type) : f.types.add(type))),
          ]),
        _groupe(t('Distance'), [
          for (final (nom, km) in [
            (t('Partout'), null),
            for (final n in const [10, 50, 100]) (t('{n} km', {'n': n}), n),
          ])
            Pastille(
              texte: nom,
              retenue: f.distanceKm == km,
              onTap: () {
                final avant = f.distanceKm;
                km == null ? _changer(() => f.distanceKm = null) : _avecPosition(() => f.distanceKm = km, () => f.distanceKm = avant);
              },
            ),
        ]),
        _groupe(t('Trier'), [
          for (final (cle, nom) in [('Pertinence', t('Pertinence')), ('Près de moi', t('Près de moi')), ('Les plus publiés', t('Les plus publiés'))])
            Pastille(
              texte: nom,
              retenue: f.tri == cle,
              onTap: () {
                final avant = f.tri;
                cle == 'Près de moi' ? _avecPosition(() => f.tri = cle, () => f.tri = avant) : _changer(() => f.tri = cle);
              },
            ),
        ]),
        Row(
          children: [
            Expanded(child: Text(t('Afficher uniquement les captures vérifiées'), style: Textes.libelle)),
            Switch(value: f.verifiees, activeTrackColor: Couleurs.ocean, onChanged: (v) => _changer(() => f.verifiees = v)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(
              onPressed: () => _changer(f.effacer),
              child: Text(
                t('Tout effacer'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Couleurs.texte),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BoutonVerre(texte: tn(nombre, 'Voir {n} lieu', 'Voir {n} lieux'), plein: true, onTap: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ],
    );
  }
}
