// E11 Carte : la carte de Google (widgets/carte_google.dart), ou chaque lieu
// est un repere en forme de photo (un petit triangle de lecture pour les
// reels). Toucher un repere ouvre son apercu en bas : voir le reel ou le
// lieu, et Y aller. A chaque arret de la carte, le serveur donne les lieux de
// la zone (GET carte), ceux qui n ont que des reels compris.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../outils/chemins.dart';
import '../donnees/modeles.dart';
import '../donnees/capture.dart';
import '../donnees/catalogue.dart';
import '../donnees/communaute.dart';
import '../donnees/lieux_enregistres.dart';
import '../donnees/session.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/feuille.dart';
import '../widgets/carte_google.dart';
import '../widgets/icone.dart';
import '../widgets/lentille.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/y_aller.dart';
import '../widgets/verre.dart';
import 'recherche.dart';

class EcranCarte extends StatefulWidget {
  const EcranCarte({super.key});

  @override
  State<EcranCarte> createState() => _EcranCarteState();
}

class _EcranCarteState extends State<EcranCarte> {
  GoogleMapController? _carte;
  // Une cle (Tout, Reels, Photos, Captures vérifiées) : traduite a l affichage.
  String _filtre = 'Tout';
  Lieu? _choisi;
  double _zoom = 6.4;

  // Ma position, trouvee avant que la carte soit prete : elle s y place en naissant.
  LatLng? _attendue;

  // Des que la carte a ete touchee (ou un repere choisi), ma position arrivee tard ne la deplace plus.
  bool _touchee = false;

  // Les lieux de la zone regardee (GET carte), en plus de ceux de l accueil.
  List<Lieu> _zone = const [];
  Timer? _attenteZone;
  int _demandeZone = 0;

  // La derniere zone demandee et ses types : une carte a peine bougee ne redemande rien.
  ({double nord, double sud, double est, double ouest})? _derniereZone;
  String _typesZone = '';

  // On laisse la carte se poser (600 ms) avant de demander la zone.
  void _zoneBouge() {
    _attenteZone?.cancel();
    _attenteZone = Timer(const Duration(milliseconds: 600), _chargerZone);
  }

  Future<void> _chargerZone({bool forcer = false}) async {
    final c = _carte;
    if (c == null) return;
    final ({double nord, double sud, double est, double ouest}) z;
    try {
      final b = await c.getVisibleRegion();
      z = (nord: b.northeast.latitude, sud: b.southwest.latitude, est: b.northeast.longitude, ouest: b.southwest.longitude);
    } catch (_) {
      return;
    }
    final types = Filtres.instance.types.toList()..sort();
    final cle = types.join(',');
    final avant = _derniereZone;
    if (!forcer && avant != null && cle == _typesZone && _presqueLaMeme(avant, z)) return;
    _derniereZone = z;
    _typesZone = cle;
    final demande = ++_demandeZone;
    final lieux = await Catalogue.instance.lieuxDeLaZone(nord: z.nord, sud: z.sud, est: z.est, ouest: z.ouest, types: types);
    if (!mounted || demande != _demandeZone) return;
    // Hors ligne : les reperes deja la restent, et le prochain arret redemande.
    if (lieux == null) {
      _derniereZone = null;
      return;
    }
    setState(() => _zone = lieux);
  }

  // Moins d un sixieme de la zone en deplacement ou en taille, sur chaque bord.
  static bool _presqueLaMeme(({double nord, double sud, double est, double ouest}) a, ({double nord, double sud, double est, double ouest}) b) {
    final h = (a.nord - a.sud).abs() / 6;
    final l = (a.est - a.ouest).abs() / 6;
    if (h == 0 || l == 0) return false;
    return (a.nord - b.nord).abs() < h && (a.sud - b.sud).abs() < h && (a.est - b.est).abs() < l && (a.ouest - b.ouest).abs() < l;
  }

  // Une pile ou une liste de publications arrivee (captures verifiees, reels) : les reperes suivent.
  void _maj() {
    if (mounted) setState(() {});
  }

  // Le point bleu de ma position : Google Maps n allume sa couche qu en la voyant passer a vrai.
  // Allumee avant la permission, elle restait eteinte meme une fois la permission donnee.
  bool _permise = false;

  Future<void> _verifierPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      final permise = p == LocationPermission.whileInUse || p == LocationPermission.always;
      if (mounted && permise != _permise) setState(() => _permise = permise);
    } catch (_) {}
  }

  // La recherche se tape ici meme : les lieux s affichent sous la barre, au fil de la frappe.
  final _texte = TextEditingController();
  final _focus = FocusNode();
  Timer? _attenteRecherche;
  bool _chercheServeur = false;
  List<Lieu> _trouves = const [];
  List<({String id, String nom, String adresse})> _google = const [];

  // Le centre de ce qu on regarde : Google cherche d abord autour.
  LatLng? _vue;

  // Ouvert par la frappe ; ferme par un choix, la carte touchee ou l effacement.
  bool _ouvert = false;
  bool get _panneau => _ouvert && _texte.text.trim().length >= 2;

  // Chaque choix a son numero : une reponse lente de Google n annule pas un choix fait depuis.
  int _demande = 0;

  void _frappe(String t) {
    _ouvert = true;
    _attenteRecherche?.cancel();
    final q = t.trim();
    if (q.length < 2) {
      setState(() {
        _trouves = const [];
        _google = const [];
        _chercheServeur = false;
      });
      return;
    }
    // Tout de suite, les lieux deja sur le telephone ; puis ceux du serveur (et de Google).
    final mots = texteSimple(q).split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    setState(() {
      _trouves = Catalogue.instance.lieux.where((l) => l.situe && mots.every(texteSimple('${l.nom} ${l.region}').contains)).take(6).toList();
      _chercheServeur = true;
    });
    _attenteRecherche = Timer(const Duration(milliseconds: 300), () async {
      final v = _vue;
      List<Lieu> lieux;
      var google = const <({String id, String nom, String adresse})>[];
      if (Communaute.instance.enLigne) {
        final r = await Catalogue.instance.suggestionsLieu(q, latitude: v?.latitude, longitude: v?.longitude);
        lieux = r?.lieux ?? const [];
        google = r?.google ?? const [];
      } else {
        lieux = (await Catalogue.instance.chercher(q))?.lieux ?? const [];
      }
      if (!mounted || _texte.text.trim() != q) return;
      final ids = <String>{};
      setState(() {
        _trouves = [..._trouves, ...lieux].where((l) => l.situe && ids.add(l.id)).take(6).toList();
        // Google ne redit pas un lieu deja propose par Discover.
        _google = google.where((g) => !_trouves.any((l) => texteSimple(l.nom) == texteSimple(g.nom))).take(5).toList();
        _chercheServeur = false;
      });
    });
  }

  void _fermerRecherche(String nom) {
    _attenteRecherche?.cancel();
    _focus.unfocus();
    _demande++;
    setState(() {
      _ouvert = false;
      _texte.text = nom;
      _trouves = const [];
      _google = const [];
      _chercheServeur = false;
    });
  }

  void _allerAuLieu(Lieu l) {
    _fermerRecherche(l.nom);
    _choisir(l);
  }

  Future<void> _allerAGoogle(({String id, String nom, String adresse}) g) async {
    _fermerRecherche(g.nom);
    _touchee = true;
    final demande = _demande;
    final p = await Catalogue.instance.positionGoogle(g.id);
    if (!mounted || demande != _demande) return;
    if (p == null) {
      bulle(context, t('Impossible de trouver ce lieu pour le moment. Réessayez.'), icone: 'alerte');
      return;
    }
    setState(() => _choisi = null);
    _aller(LatLng(p.latitude, p.longitude), 15);
  }

  @override
  void dispose() {
    Catalogue.instance.removeListener(_maj);
    _attenteZone?.cancel();
    _attenteRecherche?.cancel();
    _texte.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Catalogue.instance.addListener(_maj);
    _focus.addListener(() {
      if (_focus.hasFocus && !_ouvert && _texte.text.trim().length >= 2) {
        _frappe(_texte.text);
      } else {
        setState(() {});
      }
    });
    // En arrivant sur la carte, Discover demande la position (Android le fait une fois), puis s y place.
    WidgetsBinding.instance.addPostFrameCallback((_) => _premierePosition());
    _verifierPermission();
  }

  Future<void> _premierePosition() async {
    if (!Session.instance.position) return;
    // La derniere position connue place la carte tout de suite ; la position fraiche l ajuste.
    await _verifierPermission();
    final vite = await _derniereConnue();
    if (vite != null && mounted && !_touchee) {
      setState(() => _attendue = vite);
      _carte?.moveCamera(CameraUpdate.newLatLngZoom(vite, 12));
    }
    final p = await positionActuelle();
    await _verifierPermission();
    if (!mounted || p == null) return;
    final ici = LatLng(p.latitude, p.longitude);
    // Le point bleu de ma position s affiche des que la permission est donnee.
    if (_touchee) return;
    setState(() => _attendue = ici);
    _carte?.moveCamera(CameraUpdate.newLatLngZoom(ici, 12));
  }

  // Les reperes trop proches a ce zoom (moins de 52 px) se regroupent.
  List<List<Lieu>> get _groupes {
    final echelle = 256 * math.pow(2, _zoom) / 360;
    final groupes = <List<Lieu>>[];
    for (final l in _lieux) {
      final proche = groupes.where((g) {
        final dx = (g.first.longitude - l.longitude) * echelle;
        final dy = (g.first.latitude - l.latitude) * echelle * 1.01;
        return math.sqrt(dx * dx + dy * dy) < 52;
      }).firstOrNull;
      if (proche != null) {
        proche.add(l);
      } else {
        groupes.add([l]);
      }
    }
    return groupes;
  }

  void _aller(LatLng point, double zoom) {
    _touchee = true;
    _carte?.animateCamera(CameraUpdate.newLatLngZoom(point, zoom));
  }

  void _ouvrirGroupe(List<Lieu> g) {
    final lat = g.map((l) => l.latitude).reduce((a, b) => a + b) / g.length;
    final lon = g.map((l) => l.longitude).reduce((a, b) => a + b) / g.length;
    _aller(LatLng(lat, lon), (_zoom + 2).clamp(4.0, 18.0));
  }

  // Les reperes dessines (photo, reel, nombre, choisi), et ceux en cours de dessin.
  final _icones = <String, BitmapDescriptor>{};
  final _enDessin = <String>{};

  Set<Marker> _reperes(double dpr) => {
    for (final g in _groupes)
      if (_icone(g, dpr) case final icone?)
        Marker(
          markerId: MarkerId('${g.first.id}-${g.length}'),
          position: LatLng(g.first.latitude, g.first.longitude),
          icon: icone,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: _choisi?.id == g.first.id ? 2 : 1,
          consumeTapEvents: true,
          onTap: () => g.length == 1 ? _choisir(g.first) : _ouvrirGroupe(g),
        ),
  };

  // L icone d un groupe, si elle est prete ; sinon elle se dessine, et la carte suit.
  BitmapDescriptor? _icone(List<Lieu> g, double dpr) {
    final l = g.first;
    final seul = g.length == 1;
    final reel = seul && _aUnReel(l);
    final choisi = seul && _choisi?.id == l.id;
    final cle = '${l.id}|${g.length}|$reel|$choisi|${Couleurs.sombre}';
    final pret = _icones[cle];
    if (pret == null && _enDessin.add(cle)) {
      iconeRepere(photo: _photoDe(l), dpr: dpr, nombre: g.length, reel: reel, choisi: choisi).then((i) {
        _enDessin.remove(cle);
        if (mounted) setState(() => _icones[cle] = i);
      });
    }
    return pret;
  }

  // Ma position, si elle est permise ; sinon, autoriser ou choisir une ville.
  // La carte y va tout de suite (derniere position connue), puis suit la position fraiche.
  // « Position desactivee » seulement si elle l est vraiment (coupee ou refusee) : un GPS
  // lent n est pas une position coupee.
  Future<void> _allerAMaPosition() async {
    if (!Session.instance.position) return _positionDesactivee();
    final vite = await _derniereConnue();
    if (vite != null) _aller(vite, 14);
    final p = await positionActuelle();
    await _verifierPermission();
    if (!mounted) return;
    if (p != null) return _aller(LatLng(p.latitude, p.longitude), 14);
    if (positionManquee == SansPosition.coupee || positionManquee == SansPosition.refusee) return _positionDesactivee();
    if (vite == null) bulle(context, t('Impossible de trouver votre position pour le moment. Réessayez dans quelques secondes.'), icone: 'cible');
  }

  Future<LatLng?> _derniereConnue() async {
    if (!_permise) return null;
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  // Le serveur dit combien de reels a un lieu ; sans ce nombre, on regarde les reels deja recus.
  bool _aUnReel(Lieu l) {
    final n = l.nombreReels;
    return n != null ? n > 0 : Catalogue.instance.reels.any((r) => r.lieu == l.id);
  }

  // La pile ne porte que des photos : un lieu sans pile n a que des reels.
  bool _aDesPhotos(Lieu l) {
    final n = l.nombreReels;
    return n != null ? l.nombre > n : l.photos.isNotEmpty;
  }

  // La photo du repere : la pile, sinon l affiche d un reel du lieu deja recu.
  String _photoDe(Lieu l) => l.photos.firstOrNull ?? Catalogue.instance.reels.where((r) => r.lieu == l.id).firstOrNull?.photo ?? '';

  List<Lieu> get _lieux {
    // La pile « Sans lieu » n a pas de position : elle n est pas sur la carte.
    final masques = Catalogue.instance.masques;
    final parId = <String, Lieu>{
      for (final l in Catalogue.instance.lieux)
        if (l.situe) l.id: l,
    };
    for (final l in _zone) {
      if (l.situe && !masques.contains(l.id)) parId[l.id] = l;
    }
    final situes = parId.values;
    final base = switch (_filtre) {
      'Reels' => situes.where(_aUnReel),
      'Photos' => situes.where(_aDesPhotos),
      'Captures vérifiées' => situes.where(Filtres.instance.verifie),
      _ => situes,
    };
    // Les filtres de la feuille (pays, types, distance, captures verifiees) s appliquent aussi a la carte.
    return Filtres.instance.appliquer(base);
  }

  // Le repere choisi se centre au-dessus de son apercu (la marge du bas de la carte le compte).
  void _choisir(Lieu l) {
    _demande++;
    setState(() => _choisi = l);
    _aller(LatLng(l.latitude, l.longitude), _zoom.clamp(9.0, 18.0));
  }

  // E37 position : refusee a l inscription, on propose de l autoriser ou de
  // chercher une ville (le champ du haut cherche aussi chez Google).
  Future<void> _positionDesactivee() => montrerFeuille<void>(
    context,
    titre: t('La position est désactivée'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('Pour voir les lieux autour de vous, autorisez la position. Vous pouvez aussi chercher une ville.'), style: Textes.discret),
          const SizedBox(height: 18),
          BoutonVerre(
            texte: t('Autoriser la position'),
            plein: true,
            onTap: () async {
              Navigator.pop(f);
              setState(() => Session.instance.position = true);
              // Gardé sur le compte : le prochain rafraîchissement ne le remet pas à faux.
              if (Session.instance.connecte) Session.instance.envoyerProfil().catchError((_) {});
              // La vraie demande d Android (allumer la localisation, l autorisation, ou ses reglages
              // si elle a ete refusee pour de bon) ; jamais cette feuille en boucle.
              if (await demanderLocalisation()) {
                _allerAMaPosition();
              } else if (mounted) {
                bulle(
                  context,
                  positionManquee == SansPosition.coupee
                      ? t('La localisation est désactivée sur ce téléphone. Activez-la, puis réessayez.')
                      : t('Autorisez la position pour Discover dans les réglages d’Android, puis revenez.'),
                  icone: 'cible',
                );
              }
            },
          ),
          const SizedBox(height: 10),
          BoutonVerre(
            texte: t('Chercher une ville'),
            onTap: () {
              Navigator.pop(f);
              _focus.requestFocus();
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final bas = MediaQuery.paddingOf(context).bottom + Mesures.hautOnglets + 26;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: Stack(
        children: [
          Listener(
            onPointerDown: (_) => _touchee = true,
            child: CarteGoogle(
              centre: const LatLng(8.6, 2.2),
              zoom: 6.4,
              reperes: _reperes(MediaQuery.devicePixelRatioOf(context)),
              maPosition: Session.instance.position && _permise,
              // Le haut (recherche, filtres) et le bas (barre, apercu) : le logo
              // de Google et le centre de la carte restent dans ce qui se voit.
              padding: EdgeInsets.only(top: haut + 110, bottom: _choisi == null ? bas - 30 : bas + 150),
              onCree: (c) {
                _carte = c;
                final ici = _attendue;
                if (ici != null && !_touchee) c.moveCamera(CameraUpdate.newLatLngZoom(ici, 12));
              },
              onBouge: (camera) {
                _vue = camera.target;
                if ((camera.zoom - _zoom).abs() > 0.05) setState(() => _zoom = camera.zoom);
              },
              onArret: _zoneBouge,
              onTap: () {
                _focus.unfocus();
                _demande++;
                setState(() {
                  _ouvert = false;
                  _choisi = null;
                });
              },
            ),
          ),
          // Le haut : la recherche et les filtres, en verre sur la carte.
          Positioned(
            top: haut + 6,
            left: marge,
            right: marge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Givre(
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
                                  focusNode: _focus,
                                  textInputAction: TextInputAction.search,
                                  onChanged: _frappe,
                                  onSubmitted: (_) {
                                    final premier = _trouves.firstOrNull;
                                    if (premier != null) {
                                      _allerAuLieu(premier);
                                    } else if (_google.isNotEmpty) {
                                      _allerAGoogle(_google.first);
                                    }
                                  },
                                  style: TextStyle(fontSize: 15.5, color: Couleurs.texte),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: t('Rechercher un lieu'),
                                    hintStyle: TextStyle(fontSize: 15, color: Couleurs.discret),
                                  ),
                                ),
                              ),
                              if (_texte.text.isNotEmpty)
                                Semantics(
                                  button: true,
                                  label: t('Effacer'),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      _texte.clear();
                                      _frappe('');
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
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
                    Appuyable(
                      semantique: t('Filtres'),
                      verre: true,
                      rayonVerre: 25,
                      // Les filtres s ouvrent ici, sur la carte, au premier appui.
                      onTap: () => ouvrirFiltres(context, onChange: () => setState(() {}), nombre: () => _lieux.length).then((_) {
                        if (!mounted) return;
                        setState(() {});
                        // Les types ont pu changer : la zone se redemande avec eux.
                        _chargerZone();
                      }),
                      child: _Givre(
                        rayon: 25,
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(child: Icone('filtres', taille: 22, couleur: Couleurs.texte)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      for (final (cle, nom) in [('Tout', t('Tout')), ('Reels', t('Reels')), ('Photos', t('Photos')), ('Captures vérifiées', t('Captures vérifiées'))]) ...[
                        Pastille(texte: nom, retenue: _filtre == cle, onTap: () => setState(() => _filtre = cle)),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Revenir a ma position.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 520),
            curve: Courbes.ressort,
            right: marge,
            bottom: _choisi == null ? bas : bas + 168,
            child: Appuyable(
              semantique: t('Ma position'),
              verre: true,
              rayonVerre: 25,
              onTap: _allerAMaPosition,
              child: _Givre(
                rayon: 25,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(child: Icone('cible', taille: 23, couleur: Couleurs.texte)),
                ),
              ),
            ),
          ),
          if (_panneau)
            Positioned(
              top: haut + 62,
              left: marge,
              right: marge,
              child: _Givre(
                rayon: Mesures.rayonPlaque,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: math.max(120.0, MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom - haut - 62 - math.max(bas, 24.0))),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    children: [
                      for (final l in _trouves) _Resultat(icone: 'lieu', titre: l.nom, detail: l.region, onTap: () => _allerAuLieu(l)),
                      for (final g in _google) _Resultat(icone: 'globe', titre: g.nom, detail: g.adresse, onTap: () => _allerAGoogle(g)),
                      if (_trouves.isEmpty && _google.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _chercheServeur
                              ? const Center(child: LogoQuiTourne(taille: 22))
                              : Text(t('Aucun lieu trouvé pour « {requete} »', {'requete': _texte.text.trim()}), style: Textes.discret, textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // L apercu du repere choisi : il monte du bas, au ressort.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 560),
            curve: Courbes.ressort,
            left: marge,
            right: marge,
            bottom: _choisi == null ? -240 : bas,
            child: _choisi == null
                ? const SizedBox(height: 150)
                : _Apercu(lieu: _choisi!, reel: Catalogue.instance.reels.where((r) => r.lieu == _choisi!.id).firstOrNull, onFermer: () => setState(() => _choisi = null)),
          ),
        ],
      ),
    );
  }
}

/// Le verre sur la carte : depoli leger (lentille quand elle est la) et blanc.
/// Une ligne de resultat de la recherche sur la carte.
class _Resultat extends StatelessWidget {
  const _Resultat({required this.icone, required this.titre, required this.detail, required this.onTap});

  final String icone;
  final String titre;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: detail.isEmpty ? titre : '$titre, $detail',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(
          children: [
            Icone(icone, taille: 20, couleur: Couleurs.discret),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                  if (detail.isNotEmpty) Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: Textes.petit),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Givre extends StatelessWidget {
  const _Givre({required this.rayon, required this.child});

  final double rayon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Lentille(
    rayon: rayon,
    flou: 10,
    child: DecoratedBox(
      decoration: BoxDecoration(color: Couleurs.surface.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(rayon)),
      child: Verre(rayon: rayon, surFond: false, ombre: false, child: child),
    ),
  );
}

class _Apercu extends StatelessWidget {
  const _Apercu({required this.lieu, required this.reel, required this.onFermer});

  final Lieu lieu;
  final Reel? reel;

  /// La croix en haut a droite : la fiche descend, la carte reste ou elle est.
  final VoidCallback onFermer;

  Future<void> _yAller(BuildContext context) => yAller(context, lieu);

  @override
  Widget build(BuildContext context) {
    final r = reel;
    // Le badge du reel, ou celui de la photo devant la pile ; rien tant qu on ne le sait pas.
    final verifiee = r != null ? r.verifiee : Catalogue.instance.publicationsDe(lieu).firstOrNull?.verifiee;
    return _Givre(
      rayon: 26,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La photo touchee ouvre sa page (commentaires, informations), sans passer par le lieu.
            Appuyable(
              semantique: r != null ? t('Voir le reel') : t('Voir la photo'),
              onTap: () => context.push(ici(context, 'lieu/${lieu.id}/photo/${r?.id ?? Catalogue.instance.publicationsDe(lieu).firstOrNull?.id ?? 0}')),
              child: SizedBox(
                width: 92,
                height: 128,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PhotoArrondie(r?.photo ?? lieu.photos.firstOrNull ?? '', rayon: 16),
                    if (r != null)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '${r.duree ~/ 60}:${(r.duree % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(lieu.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2)),
                        ),
                      ),
                      Appuyable(
                        semantique: t('Fermer'),
                        onTap: onFermer,
                        child: SizedBox.square(
                          dimension: 32,
                          child: Center(child: Icone('fermer', taille: 20, couleur: Couleurs.discret)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icone('telephone', taille: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          r != null ? '${r.appareil} · ${r.pseudo}' : '${nombrePublications(lieu.nombre)}${lieu.region.isEmpty ? '' : ' · ${lieu.region}'}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: Couleurs.discret),
                        ),
                      ),
                    ],
                  ),
                  if (verifiee != null) ...[const SizedBox(height: 6), BadgeCapture(verifie: verifiee, court: true)],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: BoutonVerre(
                          texte: r != null ? t('Voir le reel') : t('Voir le lieu'),
                          // Ce reel-la, dans son lieu (comme une publication trouvee par la recherche).
                          onTap: () => context.push(ici(context, r?.id != null ? 'lieu/${lieu.id}/photo/${r!.id}' : 'lieu/${lieu.id}')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BoutonVerre(texte: t('Y aller'), plein: true, large: false, widgetIcone: const Icone('y-aller', taille: 19), onTap: () => _yAller(context)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
