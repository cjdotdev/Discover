// Choisir le son d un reel, comme sur TikTok, Instagram, Snapchat ou WhatsApp : le catalogue
// (« Pour vous », les favoris, les ambiances, la recherche), l ecoute d un passage, le
// choix de l extrait sur le dessin de l onde, et les deux volumes (le son d origine, la musique).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:image_picker/image_picker.dart';

import '../donnees/sons.dart';
import '../outils/api.dart' show ErreurApi;
import '../outils/appareil.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import 'banniere.dart';
import 'champ.dart';
import 'feuille.dart';
import 'icone.dart';
import 'verre.dart';

/// Le nom d une ambiance du catalogue.
String nomAmbiance(String c) => switch (c) {
  'afro' => t('Afro et monde'),
  'joyeux' => t('Joyeux'),
  'energie' => t('Énergique'),
  'plage' => t('Plage et soleil'),
  'calme' => t('Calme'),
  'aventure' => t('Aventure'),
  'favoris' => t('Favoris'),
  'miens' => t('Mes sons'),
  'membres' => t('Sons des membres'),
  _ => c,
};

/// « 3:25 »
String dureeSon(int ms) => '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

/// L ecoute d un son du catalogue, une seule a la fois dans toute l application.
class EcouteSon {
  EcouteSon._();
  static final instance = EcouteSon._();

  AudioPlayer? _lecteur;

  /// Le son qui joue (son identifiant), nul sinon.
  final enCours = ValueNotifier<String?>(null);

  Future<void> ecouter(Son s, {int? depuisMs}) async {
    final lecteur = _lecteur ??= AudioPlayer();
    enCours.value = s.id;
    try {
      await lecteur.setUrl(s.url);
      await lecteur.seek(Duration(milliseconds: depuisMs ?? s.debutConseilleMs));
      await lecteur.setLoopMode(LoopMode.one);
      if (enCours.value == s.id) unawaited(lecteur.play());
    } catch (_) {
      if (enCours.value == s.id) enCours.value = null;
    }
  }

  Future<void> arreter() async {
    enCours.value = null;
    await _lecteur?.stop();
  }
}

/// La pochette d un son : un carre de sa couleur (tiree de son titre) et une note.
class Pochette extends StatelessWidget {
  const Pochette({super.key, required this.son, this.taille = 52, this.enLecture = false});

  final Son son;
  final double taille;
  final bool enLecture;

  @override
  Widget build(BuildContext context) {
    final teinte = (son.titre.codeUnits.fold<int>(0, (a, b) => a + b) * 47) % 360;
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Couleurs.hsl(teinte.toDouble(), 45, 42), borderRadius: BorderRadius.circular(taille * 0.22)),
      child: Icone(enLecture ? 'pause' : 'musique', taille: taille * 0.42, couleur: Colors.white),
    );
  }
}

/// Le catalogue : rend le son choisi (« Utiliser »), nul si on ferme.
Future<Son?> choisirSon(BuildContext context) async {
  final s = await montrerFeuille<Son>(context, titre: t('Sons'), contenu: (_) => const _Catalogue());
  unawaited(EcouteSon.instance.arreter());
  return s;
}

class _Catalogue extends StatefulWidget {
  const _Catalogue();

  @override
  State<_Catalogue> createState() => _CatalogueState();
}

class _CatalogueState extends State<_Catalogue> {
  final _recherche = TextEditingController();
  final _defile = ScrollController();
  Timer? _attente;

  // Nul : « Pour vous », les plus utilises.
  String? _ambiance;
  List<Son>? _sons;
  String? _suite;
  bool _charge = false;
  bool _erreur = false;
  String? _choisi;

  // Une reponse arrivee apres un autre choix (une autre ambiance, une autre recherche) est ignoree.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _defile.addListener(() {
      if (_defile.position.pixels > _defile.position.maxScrollExtent - 300) _plus();
    });
    _charger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    _defile.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final g = ++_generation;
    setState(() {
      _sons = null;
      _suite = null;
      _erreur = false;
    });
    try {
      final p = await Sons.instance.page(categorie: _ambiance, recherche: _recherche.text);
      if (!mounted || g != _generation) return;
      setState(() {
        _sons = p.sons;
        _suite = p.suite;
      });
    } catch (_) {
      if (mounted && g == _generation) setState(() => _erreur = true);
    }
  }

  Future<void> _plus() async {
    final suite = _suite;
    if (suite == null || _charge) return;
    final g = _generation;
    _charge = true;
    try {
      final p = await Sons.instance.page(categorie: _ambiance, recherche: _recherche.text, curseur: suite);
      if (mounted && g == _generation) {
        setState(() {
          _sons = [...?_sons, ...p.sons];
          _suite = p.suite;
        });
      }
    } catch (_) {}
    _charge = false;
  }

  // L import en cours (le son d une video, un fichier du telephone).
  bool _importe = false;

  Future<void> _importer({required bool depuisVideo}) async {
    String? chemin;
    if (depuisVideo) {
      final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (video == null || !mounted) return;
      setState(() => _importe = true);
      chemin = await Appareil.extraireSon(video.path);
      if (chemin == null) {
        if (mounted) {
          setState(() => _importe = false);
          bulle(context, t('Cette vidéo n’a pas de son.'), icone: 'muet');
        }
        return;
      }
    } else {
      chemin = await Appareil.choisirAudio();
      if (chemin == null || !mounted) return;
    }
    final titre = await _titre();
    if (titre == null || !mounted) {
      if (mounted) setState(() => _importe = false);
      return;
    }
    setState(() => _importe = true);
    try {
      final s = await Sons.instance.importer(chemin, titre: titre);
      if (mounted) Navigator.of(context).pop(s);
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() => _importe = false);
      bulle(context, e.message, icone: 'alerte');
    } catch (_) {
      if (!mounted) return;
      setState(() => _importe = false);
      bulle(context, t('Impossible d’importer ce son pour le moment. Réessayez.'), icone: 'alerte');
    }
  }

  // Le nom du son importe (« Son original » par defaut) ; nul : abandon.
  Future<String?> _titre() {
    final champ = TextEditingController(text: t('Son original'));
    return montrerFeuille<String>(
      context,
      titre: t('Nom du son'),
      contenu: (f) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChampVerre(icone: 'musique', libelle: t('Nom du son'), controleur: champ),
            const SizedBox(height: 10),
            Text(t('Importez seulement un son que vous avez le droit d’utiliser. Les autres membres pourront le réutiliser.'), style: Textes.petit),
            const SizedBox(height: 14),
            BoutonVerre(texte: t('Importer'), plein: true, onTap: () => Navigator.pop(f, champ.text)),
          ],
        ),
      ),
    ).whenComplete(champ.dispose);
  }

  void _chercher(String _) {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 350), _charger);
  }

  void _toucher(Son s) {
    final ecoute = EcouteSon.instance;
    if (_choisi == s.id && ecoute.enCours.value == s.id) {
      ecoute.arreter();
    } else {
      setState(() => _choisi = s.id);
      ecoute.ecouter(s);
    }
  }

  Future<void> _favori(Son s) async {
    final garder = !s.favori;
    void remplacer(Son par) => setState(() => _sons = [for (final x in _sons ?? const <Son>[]) x.id == s.id ? par : x]);
    remplacer(s.avecFavori(garder));
    try {
      await Sons.instance.favori(s.id, garder);
      if (mounted) bulle(context, garder ? t('Ajouté à vos favoris.') : t('Retiré de vos favoris.'), icone: 'enregistrer');
    } catch (_) {
      if (!mounted) return;
      remplacer(s);
      bulle(context, t('Impossible pour le moment. Réessayez.'), icone: 'alerte');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ambiances = <String?>[null, 'favoris', 'miens', ...Sons.instance.categories];
    if (_importe) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.4,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 14),
              Text(t('Importation du son…'), style: Textes.discret),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          // Un son a soi : celui d une video, ou un fichier du telephone.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: BoutonVerre(texte: t('Son d’une vidéo'), icone: 'reels', onTap: () => _importer(depuisVideo: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BoutonVerre(texte: t('Son du téléphone'), icone: 'musique', onTap: () => _importer(depuisVideo: false)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ChampVerre(icone: 'loupe', indice: t('Rechercher un son ou un artiste'), controleur: _recherche, onChanged: _chercher, action: TextInputAction.search),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ambiances.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final a = ambiances[i];
                return Pastille(
                  texte: a == null ? t('Pour vous') : nomAmbiance(a),
                  retenue: _ambiance == a,
                  onTap: () {
                    if (_ambiance == a) return;
                    _ambiance = a;
                    _charger();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _liste()),
        ],
      ),
    );
  }

  Widget _liste() {
    final sons = _sons;
    if (_erreur) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('Impossible de charger les sons.'), style: Textes.discret),
            const SizedBox(height: 12),
            BoutonVerre(texte: t('Réessayer'), large: false, onTap: _charger),
          ],
        ),
      );
    }
    if (sons == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (sons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            switch (_ambiance) {
              'favoris' => t('Vos sons favoris s’affichent ici.'),
              'miens' => t('Les sons que vous importez s’affichent ici.'),
              _ => t('Aucun son trouvé.'),
            },
            textAlign: TextAlign.center,
            style: Textes.discret,
          ),
        ),
      );
    }
    return ValueListenableBuilder<String?>(
      valueListenable: EcouteSon.instance.enCours,
      builder: (context, joue, _) => ListView.builder(
        controller: _defile,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        itemCount: sons.length,
        itemBuilder: (context, i) {
          final s = sons[i];
          final choisi = _choisi == s.id;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toucher(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Pochette(son: s, enLecture: joue == s.id),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Textes.libelle),
                        const SizedBox(height: 2),
                        Text(
                          [s.artiste, dureeSon(s.dureeMs), if (s.nombreReels > 0) tn(s.nombreReels, '{n} reel', '{n} reels')].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Textes.petit,
                        ),
                      ],
                    ),
                  ),
                  Appuyable(
                    onTap: () => _favori(s),
                    semantique: s.favori ? t('Retirer des favoris') : t('Ajouter aux favoris'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icone(s.favori ? 'coche' : 'enregistrer', taille: 20, couleur: s.favori ? Couleurs.ocean : Couleurs.discret),
                    ),
                  ),
                  if (choisi) ...[const SizedBox(width: 4), BoutonVerre(texte: t('Utiliser'), plein: true, large: false, onTap: () => Navigator.of(context).pop(s))],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Le dessin de l onde d un son, et la fenetre de l extrait (de [debut] a [fin], de 0 a 1).
class _Onde extends CustomPainter {
  _Onde(this.forme, this.debut, this.fin, this.encre, this.eteinte);

  final List<int> forme;
  final double debut, fin;
  final Color encre, eteinte;

  @override
  void paint(Canvas canvas, Size size) {
    final n = forme.isEmpty ? 60 : forme.length;
    final pas = size.width / n;
    final trait = Paint()
      ..strokeWidth = (pas * 0.6).clamp(1.0, 4.0)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final v = forme.isEmpty ? 40 : forme[i];
      final h = (size.height * (0.12 + 0.88 * v / 100)).clamp(2.0, size.height);
      final x = (i + 0.5) * pas;
      final dedans = (i + 0.5) / n >= debut && (i + 0.5) / n <= fin;
      trait.color = dedans ? encre : eteinte;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), trait);
    }
    // Le cadre de l extrait.
    final cadre = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = encre;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(debut * size.width, 0, fin * size.width, size.height), const Radius.circular(10)), cadre);
  }

  @override
  bool shouldRepaint(_Onde o) => o.debut != debut || o.fin != fin || o.encre != encre;
}

/// Choisir d ou part la musique : la fenetre de la duree du reel glisse sur l onde. Rend le debut (ms).
Future<int?> choisirExtrait(BuildContext context, MusiqueChoisie m, {required int dureeReelMs}) async {
  final son = m.son;
  final total = son.dureeMs <= 0 ? 1 : son.dureeMs;
  final longueur = (dureeReelMs / total).clamp(0.02, 1.0);
  var debut = (m.debutMs / total).clamp(0.0, 1 - longueur);
  unawaited(EcouteSon.instance.ecouter(son, depuisMs: m.debutMs));
  final r = await montrerFeuille<int>(
    context,
    titre: t('Choisir l’extrait'),
    contenu: (f) => StatefulBuilder(
      builder: (context, maj) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(son.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Textes.libelle),
            const SizedBox(height: 4),
            Text(t('Faites glisser le cadre. Le reel commence à {temps}.', {'temps': dureeSon((debut * total).round())}), style: Textes.petit),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => maj(() => debut = (debut + d.delta.dx / c.maxWidth).clamp(0.0, 1 - longueur)),
                onHorizontalDragEnd: (_) => EcouteSon.instance.ecouter(son, depuisMs: (debut * total).round()),
                onTapUp: (d) {
                  maj(() => debut = (d.localPosition.dx / c.maxWidth - longueur / 2).clamp(0.0, 1 - longueur));
                  EcouteSon.instance.ecouter(son, depuisMs: (debut * total).round());
                },
                child: CustomPaint(size: Size(c.maxWidth, 72), painter: _Onde(son.forme, debut, debut + longueur, Couleurs.texte, Couleurs.pisteEteinte)),
              ),
            ),
            const SizedBox(height: 18),
            BoutonVerre(texte: t('Appliquer'), plein: true, onTap: () => Navigator.pop(f, (debut * total).round())),
          ],
        ),
      ),
    ),
  );
  unawaited(EcouteSon.instance.arreter());
  return r;
}

/// Les deux volumes, de 0 a 100. [enDirect] : l aperçu suit les curseurs.
Future<MusiqueChoisie?> reglerVolumes(BuildContext context, MusiqueChoisie m, {required bool sonOrigine, required void Function(int origine, int musique) enDirect}) {
  var origine = sonOrigine ? m.volumeOrigine : 0;
  var musique = m.volume;
  Widget curseur(String nom, int valeur, ValueChanged<int>? changer) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(nom, style: Textes.libelle)),
          Text('$valeur %', style: Textes.petit),
        ],
      ),
      Slider(value: valeur.toDouble(), max: 100, divisions: 20, activeColor: Couleurs.texte, inactiveColor: Couleurs.pisteEteinte, onChanged: changer == null ? null : (v) => changer(v.round())),
    ],
  );
  return montrerFeuille<MusiqueChoisie>(
    context,
    titre: t('Volume'),
    contenu: (f) => StatefulBuilder(
      builder: (context, maj) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            curseur(
              t('Son d’origine'),
              origine,
              sonOrigine
                  ? (v) {
                      maj(() => origine = v);
                      enDirect(origine, musique);
                    }
                  : null,
            ),
            if (!sonOrigine) Text(t('Le son d’origine est coupé.'), style: Textes.petit),
            const SizedBox(height: 6),
            curseur(t('Musique'), musique, (v) {
              maj(() => musique = v);
              enDirect(origine, musique);
            }),
            const SizedBox(height: 14),
            BoutonVerre(
              texte: t('Appliquer'),
              plein: true,
              onTap: () => Navigator.pop(f, m.copie(volume: musique, volumeOrigine: origine)),
            ),
          ],
        ),
      ),
    ),
  );
}
