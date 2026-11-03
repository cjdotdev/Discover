// Creer : E12 le choix (photo, reel, galerie), E32 autoriser une seule fois,
// E28 le montage et E29 le son, E15 ce que le
// fichier ne dit pas, E14 les details, E30 choisir le lieu, E16 et E26 les
// envois, et le lot (jusqu a 10 photos ou videos d un coup, une publication
// chacune). Les photos et les reels se prennent avec l appareil photo du
// telephone, son interface et tous ses modes : rien ne tourne dans USW
// pendant qu on filme, donc rien ne chauffe. La photo prise ou importee est
// lue ici (EXIF : telephone, date, position, donnees/capture.dart) ; le lot 3
// branchera l envoi par morceaux et R2.
import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../donnees/capture.dart';
import '../donnees/modeles.dart';
import '../donnees/catalogue.dart';
import '../donnees/communaute.dart';
import '../outils/appareil.dart';
import '../outils/langue.dart';
import '../outils/photo_profil.dart';
import '../donnees/envois.dart';
import '../donnees/lifestyle.dart';
import '../donnees/mes_publications.dart';
import '../donnees/sons.dart';
import '../donnees/telechargements.dart';
import '../outils/chemins.dart';
import '../outils/reprise.dart';
import '../outils/retour_auto.dart';
import '../outils/type_media.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/champ.dart';
import '../widgets/feuille.dart';
import '../widgets/carte_google.dart';
import '../widgets/icone.dart';
import '../widgets/lentille.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/sons.dart';
import '../widgets/verre.dart';
import 'etats.dart';
import 'recherche.dart' show texteSimple;

/// Tourner un reel avec ce son (« Utiliser ce son », la page d un son) : l appareil photo, puis le
/// montage, ou le son est deja choisi.
void tournerAvecLeSon(BuildContext context, Son son) {
  if (!Communaute.instance.enLigne) {
    bulle(context, t('Connectez-vous pour publier. Un code vous sera envoyé par e-mail.'), icone: 'profil');
    context.push('/entree');
    return;
  }
  musiqueDuReel = MusiqueChoisie(son, debutMs: son.debutConseilleMs);
  _pourLifestyle(false);
  context.push(_autorise ? '/creer/prise?quoi=reel' : '/creer/autoriser?quoi=reel');
}

/// Les autorisations ne se demandent qu une fois (gardees d une ouverture a l autre).
bool _autorise = false;
const _cleAutorise = 'creer_autorise';

/// Au demarrage : les autorisations de Creer ont-elles deja ete donnees ?
Future<void> chargerCreer() async {
  try {
    final p = await SharedPreferences.getInstance();
    _autorise = p.getBool(_cleAutorise) ?? false;
    // Android avait ferme Discover pendant une prise pour mon lifestyle : elle y reste.
    pourMonLifestyle = p.getBool(_cleLifestyle) ?? false;
  } catch (_) {}
}

const _cleLifestyle = 'creer_pour_lifestyle';

/// Garde aussi le choix sur le telephone : une prise reprise apres coup ne change pas de place.
void _pourLifestyle(bool oui) {
  pourMonLifestyle = oui;
  SharedPreferences.getInstance().then((p) => p.setBool(_cleLifestyle, oui)).ignore();
}

/// La page qui suit une capture : les details si tout est la, sinon ce que
/// le fichier ne dit pas (E15).
String _suite(Capture c) => c.verifiee ? '/creer/details' : '/creer/completer';

/// « Sans lieu » est le nom de la pile, garde tel quel : traduit a l affichage seulement.
String _vu(String lieu) => lieu == 'Sans lieu' ? t('Sans lieu') : lieu;

/// Android avait ferme USW pendant la prise : on reprend la ou on en etait.
Future<void> reprendrePrise(BuildContext context) async {
  final retrouvee = priseRetrouvee;
  priseRetrouvee = null;
  if (retrouvee == null) return;
  final (prise, chemin) = retrouvee;
  if (prise == Prise.profil) {
    await garderPhotoProfil(chemin);
    if (context.mounted) bulle(context, t('Photo de profil mise à jour.'), icone: 'coche');
    return;
  }
  context.push(Uri(path: '/creer/prise', queryParameters: {'quoi': prise == Prise.reel ? 'reel' : 'photo', 'fichier': chemin}).toString());
}

// ------------------------------------------------------------ la prise

/// La prise : un ecran noir s ouvre, puis l appareil photo du telephone, en
/// grand, avec tous ses modes (ou la galerie). Au retour, on voit la prise
/// elle-meme pendant sa lecture (lieu, telephone), jamais l accueil.
class EcranPrise extends StatefulWidget {
  const EcranPrise({super.key, required this.quoi, this.fichier});

  /// photo, reel ou galerie.
  final String quoi;

  /// Une prise deja faite (USW avait ete ferme pendant la prise).
  final String? fichier;

  @override
  State<EcranPrise> createState() => _EcranPriseState();
}

class _EcranPriseState extends State<EcranPrise> {
  String? _apercu;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lancer());
  }

  void _fermer([String? pourquoi]) {
    if (!mounted) return;
    if (pourquoi != null) bulle(context, pourquoi, icone: 'alerte');
    context.pop();
  }

  Future<void> _lancer() async {
    Future<Position?>? position;
    String chemin;
    bool video;
    DateTime? date;
    var priseAvecUsw = true;

    if (widget.fichier != null) {
      chemin = widget.fichier!;
      final type = await typeDeMedia(chemin);
      if (type == null) return _fermer(t('Ce fichier n’est pas une photo ni une vidéo : Discover ne peut pas le publier.'));
      video = type == TypeMedia.video;
    } else if (widget.quoi == 'galerie') {
      List<XFile> medias;
      try {
        medias = await ImagePicker().pickMultipleMedia(limit: maxLot, requestFullMetadata: true);
      } catch (_) {
        return _fermer(t("Impossible d'ouvrir la galerie."));
      }
      if (medias.isEmpty) return _fermer();
      if (medias.length > maxLot) {
        if (mounted) bulle(context, t('{max} fichiers maximum : les {max} premiers sont gardés.', {'max': maxLot}), icone: 'image');
        medias = medias.sublist(0, maxLot);
      }
      // Seulement les photos et les videos, reconnues a leur contenu : un texte ou un PDF choisi
      // la ne part pas (il restait sinon sur le telephone, jamais publie).
      final types = await Future.wait([for (final m in medias) typeDeMedia(m.path)]);
      final gardes = [
        for (var i = 0; i < medias.length; i++)
          if (types[i] case final type?) (medias[i].path, type == TypeMedia.video),
      ];
      if (gardes.isEmpty) return _fermer(t('Ce fichier n’est pas une photo ni une vidéo : Discover ne peut pas le publier.'));
      if (gardes.length < medias.length && mounted) bulle(context, t('Seules les photos et les vidéos sont gardées.'), icone: 'image');
      if (gardes.length > 1) {
        return _lireLot([for (final (c, v) in gardes) (c, v, null)], priseAvecUsw: false);
      }
      (chemin, video) = gardes.first;
      priseAvecUsw = false;
    } else {
      final reel = widget.quoi == 'reel';
      // Les fenetres d Android (localisation, permission) avant l appareil photo ;
      // puis la position se cherche pendant qu on prend la photo.
      await preparerPosition();
      // Une fois : revenir tout seul apres la prise (s afficher par-dessus l appareil photo).
      if (mounted) await proposerRetourAuto(context);
      position = positionActuelle(demander: false);
      await noterPrise(reel ? Prise.reel : Prise.photo);
      List<PriseFaite> prises;
      try {
        prises = await Appareil.ouvrir(video: reel);
      } on PlatformException catch (e) {
        if (e.code != 'sans_acces') {
          await finPrise();
          return _fermer(t("Impossible d'ouvrir l'appareil photo."));
        }
        // La galerie refusee : l appareil photo en ecran simple, qui rend le fichier.
        if (mounted) bulle(context, t("Sans accès à vos photos, l'appareil photo s'ouvre en mode simple."), icone: 'camera');
        try {
          final f = reel
              ? await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60))
              : await ImagePicker().pickImage(source: ImageSource.camera, requestFullMetadata: true);
          prises = [if (f != null) PriseFaite(f.path, video: reel, date: DateTime.now())];
        } catch (_) {
          prises = const [];
        }
      } catch (_) {
        await finPrise();
        return _fermer(t("Impossible d'ouvrir l'appareil photo."));
      }
      await finPrise();
      if (prises.isEmpty) {
        return _fermer();
      }
      if (prises.length > 1) {
        final gardees = prises.take(maxLot).toList();
        if (prises.length > maxLot && mounted) bulle(context, t('{n} prises : les {max} premières sont gardées.', {'n': prises.length, 'max': maxLot}), icone: 'camera');
        return _lireLot([for (final p in gardees) (p.chemin, p.video, p.date)], priseAvecUsw: true, position: position);
      }
      final prise = prises.first;
      chemin = prise.chemin;
      video = prise.video;
      date = prise.date;
    }
    if (!mounted) return;
    setState(() {
      _message = t('Lecture du lieu et du téléphone…');
      if (!video) _apercu = chemin;
    });
    // Pas plus de 4 s d attente pour la position : sinon la derniere connue.
    final enAttente = position?.timeout(const Duration(seconds: 4), onTimeout: () => Geolocator.getLastKnownPosition().catchError((_) => null));

    if (video) {
      final vignette = Appareil.vignette(chemin).then((v) {
        if (v != null && mounted) setState(() => _apercu = v);
        return v;
      });
      final r = await lireReel(chemin);
      final c = Capture.courante = await lireCapture(r.chemin, video: true, priseAvecUsw: priseAvecUsw, position: enAttente, date: date, lireDans: chemin);
      c.vignette = await vignette;
      if (!mounted) return;
      if (r.coupee) bulle(context, t('Vidéo de {duree} : les 60 premières secondes sont gardées.', {'duree': _duree(r.dureeAvant)}), icone: 'ciseaux');
      context.pushReplacement('/creer/montage');
    } else {
      final c = Capture.courante = await lireCapture(chemin, priseAvecUsw: priseAvecUsw, position: enAttente, date: date);
      if (mounted) context.pushReplacement(_suite(c));
    }
  }

  /// Plusieurs fichiers : chacun est lu (son telephone, sa date, son lieu), une video
  /// est coupee a 60 s, puis le lot s ouvre pour tout verifier avant de publier.
  Future<void> _lireLot(List<(String, bool, DateTime?)> fichiers, {required bool priseAvecUsw, Future<Position?>? position}) async {
    final enAttente = position?.timeout(const Duration(seconds: 4), onTimeout: () => Geolocator.getLastKnownPosition().catchError((_) => null));
    final lot = <Capture>[];
    var coupees = 0;
    for (var i = 0; i < fichiers.length; i++) {
      final (chemin, video, date) = fichiers[i];
      if (!mounted) return;
      setState(() {
        _message = t('Lecture {i} sur {n}…', {'i': i + 1, 'n': fichiers.length});
        if (!video) _apercu = chemin;
      });
      try {
        if (video) {
          final v = await preparerVideo(chemin);
          if (v.coupee) coupees++;
          final c = await lireCapture(v.chemin, video: true, priseAvecUsw: priseAvecUsw, position: enAttente, date: date, lireDans: chemin);
          c
            ..duree = v.secondes
            ..vignette = await Appareil.vignette(chemin);
          // Sans couverture (un format que le telephone ne sait pas lire), pas de publication possible.
          if (c.vignette == null) continue;
          if (mounted) setState(() => _apercu = c.vignette);
          lot.add(c);
        } else {
          lot.add(await lireCapture(chemin, priseAvecUsw: priseAvecUsw, position: enAttente, date: date));
        }
      } catch (_) {
        // Un fichier illisible est laisse de cote ; les autres continuent.
      }
    }
    if (!mounted) return;
    if (lot.isEmpty) return _fermer(t('Impossible de lire ces fichiers.'));
    if (lot.length < fichiers.length) bulle(context, tn(fichiers.length - lot.length, '{n} fichier illisible a été ignoré.', '{n} fichiers illisibles ont été ignorés.'), icone: 'alerte');
    if (coupees > 0) {
      bulle(context, tn(coupees, 'Une vidéo de plus de 60 s : ses 60 premières secondes sont gardées.', '{n} vidéos de plus de 60 s : leurs 60 premières secondes sont gardées.'), icone: 'ciseaux');
    }
    Capture.lot = lot;
    context.pushReplacement('/creer/lot');
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_apercu != null) Image.file(File(_apercu!), fit: BoxFit.contain, cacheWidth: 1080, gaplessPlayback: true),
          if (_message != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 40,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text(
                      _message!,
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

String _duree(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Le plus de fichiers choisis d un coup (la galerie, ou plusieurs prises).
const maxLot = 10;

/// Une video prete a publier, avec sa duree ; au-dela de 60 s, seules les
/// 60 premieres secondes sont gardees (coupees sans reencoder).
Future<({String chemin, bool coupee, int dureeAvant, int secondes})> preparerVideo(String chemin) async {
  var secondes = await _secondes(chemin);
  final avant = secondes;
  var coupee = false;
  if (secondes > 60) {
    final court = await Appareil.couper(chemin, const Duration(seconds: 60));
    if (court != null) {
      chemin = court;
      secondes = 60;
      coupee = true;
    }
  }
  return (chemin: chemin, coupee: coupee, dureeAvant: avant, secondes: secondes.clamp(1, 60));
}

/// La video devient la sequence du reel (pour le montage).
Future<({String chemin, bool coupee, int dureeAvant, int secondes})> lireReel(String chemin) async {
  final v = await preparerVideo(chemin);
  sequencesDuReel
    ..clear()
    ..add((v.chemin, v.secondes));
  return v;
}

Future<int> _secondes(String chemin) async {
  final lecteur = VideoPlayerController.file(File(chemin));
  try {
    await lecteur.initialize();
    return lecteur.value.duration.inSeconds;
  } catch (_) {
    return 0;
  } finally {
    await lecteur.dispose();
  }
}

// ------------------------------------------------------------ E12 creer

/// Ce qui se prepare est pour mon lifestyle (hors de l accueil de Discover) : vrai depuis la page de
/// mon lifestyle, faux depuis Creer.
bool pourMonLifestyle = false;

void ouvrirCreer(BuildContext context) {
  // Publier demande un compte : ce qui part va sur le serveur, au nom de son auteur.
  if (!Communaute.instance.enLigne) {
    bulle(context, t('Connectez-vous pour publier. Un code vous sera envoyé par e-mail.'), icone: 'profil');
    context.push('/entree');
    return;
  }
  _pourLifestyle(false);
  _feuilleCreer(context);
}

/// Ajouter des photos ou des videos a mon lifestyle : les memes choix que Creer.
void ouvrirCreerPourLifestyle(BuildContext context) {
  _pourLifestyle(true);
  _feuilleCreer(context);
}

void _feuilleCreer(BuildContext context) => montrerFeuille<void>(
  context,
  titre: pourMonLifestyle ? t('Ajouter à mon lifestyle') : t('Créer'),
  contenu: (f) {
    void aller(String route) {
      Navigator.pop(f);
      context.push(route);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionCreer(
            icone: 'camera',
            titre: t('Prendre une photo'),
            texte: t("Avec l'appareil photo du téléphone et tous ses modes"),
            onTap: () => aller(_autorise ? '/creer/prise?quoi=photo' : '/creer/autoriser?quoi=photo'),
          ),
          _OptionCreer(
            icone: 'reels',
            titre: t('Tourner un reel'),
            texte: t("Avec l'appareil photo du téléphone, 60 secondes maximum"),
            onTap: () {
              // Un nouveau reel part sans musique (« Utiliser ce son » en donne une).
              musiqueDuReel = null;
              aller(_autorise ? '/creer/prise?quoi=reel' : '/creer/autoriser?quoi=reel');
            },
          ),
          _OptionCreer(icone: 'image', titre: t('Importer depuis la galerie'), texte: t("Jusqu'à 10 photos ou vidéos à la fois, même anciennes"), onTap: () => aller('/creer/prise?quoi=galerie')),
        ],
      ),
    );
  },
);

class _OptionCreer extends StatelessWidget {
  const _OptionCreer({required this.icone, required this.titre, required this.texte, required this.onTap});

  final String icone;
  final String titre;
  final String texte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // La pastille de la barre d onglets : du verre clair et son filet de lumiere.
          SizedBox(
            width: 50,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Sur le blanc de la feuille, un verre un peu plus sombre qu elle, pour se voir.
                color: Couleurs.sombre ? Colors.white.withValues(alpha: 0.1) : Couleurs.texte.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: CustomPaint(
                foregroundPainter: RefletVerre(rayon: 16, nuit: Couleurs.sombre),
                child: Center(child: Icone(icone, taille: 25, couleur: Couleurs.texte)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(texte, style: TextStyle(fontSize: 13, color: Couleurs.discret)),
              ],
            ),
          ),
          Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------ E32 autoriser

class EcranAutoriser extends StatefulWidget {
  const EcranAutoriser({super.key, this.quoi = 'photo'});

  /// Ce qui suit : une photo ou un reel.
  final String quoi;

  @override
  State<EcranAutoriser> createState() => _EcranAutoriserState();
}

class _EcranAutoriserState extends State<EcranAutoriser> {
  String _telephone = t('Le modèle');

  @override
  void initState() {
    super.initState();
    modeleDuTelephone().then((m) {
      if (mounted) setState(() => _telephone = m);
    });
  }

  Future<void> _autoriser() async {
    _autorise = true;
    SharedPreferences.getInstance().then((p) => p.setBool(_cleAutorise, true)).ignore();
    // La position est demandee ici, une fois ; la camera, par l appareil photo.
    await preparerPosition();
    if (mounted) context.pushReplacement('/creer/prise?quoi=${widget.quoi}');
  }

  @override
  Widget build(BuildContext context) => PageFormulaire(
    centre: false,
    enfants: [
      const SizedBox(height: 10),
      Center(
        child: Verre(
          rayon: 44,
          child: SizedBox(
            width: 88,
            height: 88,
            child: Center(child: Icone('camera', taille: 40, couleur: Couleurs.texte)),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Titre(t('Une seule fois'), style: Textes.titre, centre: true),
      const SizedBox(height: 10),
      Text(
        t("Prenez vos photos avec l'appareil photo de votre téléphone et tous ses modes. Discover y ajoute la position et le modèle du téléphone : elles obtiennent le badge Capture vérifiée."),
        style: Textes.discret,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 22),
      // Ce que Discover ajoute, pour information : le badge en depend, il n y a rien a choisir.
      for (final (icone, titre, texte) in [
        ('cible', t('Position'), t('Ajoutée à chaque photo et à chaque reel.')),
        ('telephone', t('Modèle du téléphone'), t('{modele}, lu sur l’appareil.', {'modele': _telephone})),
      ]) ...[
        MergeSemantics(
          child: Plaque(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icone(icone, taille: 24, couleur: Couleurs.texte),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: Textes.libelle),
                      Text(texte, style: Textes.petit),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ],
    pied: Column(
      children: [
        BoutonVerre(texte: t('Autoriser'), plein: true, onTap: _autoriser),
        const SizedBox(height: 8),
        Lien(t('Plus tard'), discret: true, onTap: () => context.pop()),
      ],
    ),
  );
}

// ------------------------------------------------------------ E28 montage : couper, le son

/// Les sequences du reel en cours : le fichier video et sa duree en secondes,
/// de l appareil photo au montage.
final sequencesDuReel = <(String, int)>[];

class EcranMontage extends StatefulWidget {
  const EcranMontage({super.key});

  @override
  State<EcranMontage> createState() => _EcranMontageState();
}

class _EcranMontageState extends State<EcranMontage> {
  // La sequence du reel : son fichier et sa duree en secondes.
  late (String, int)? _sequence = sequencesDuReel.firstOrNull;

  // Le son d origine : coupe, la piste audio est retiree a la sortie du montage.
  bool _son = true;
  bool _travail = false;

  // La lecture de la sequence, en boucle.
  VideoPlayerController? _lecteur;

  // La musique du catalogue (choisie ici, ou avec « Utiliser ce son ») : elle joue avec la video,
  // reprend a son extrait a chaque tour, et part avec le reel (le serveur la mele a la video).
  MusiqueChoisie? _musique = musiqueDuReel;
  AudioPlayer? _audio;
  Duration _derniere = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (_sequence != null) _charger();
  }

  @override
  void dispose() {
    _lecteur?.removeListener(_suivreLecture);
    _lecteur?.dispose();
    _audio?.dispose();
    super.dispose();
  }

  void _suivreLecture() {
    final lecteur = _lecteur;
    if (lecteur != null && _audio != null) {
      final v = lecteur.value;
      // La video repart du debut : la musique aussi, a son extrait.
      if (v.position + const Duration(milliseconds: 400) < _derniere) _audio!.seek(Duration(milliseconds: _musique?.debutMs ?? 0));
      _derniere = v.position;
      if (v.isPlaying && !_audio!.playing) {
        _audio!.play();
      } else if (!v.isPlaying && _audio!.playing) {
        _audio!.pause();
      }
    }
    if (mounted) setState(() {});
  }

  // Les volumes de l apercu : celui de la video (le son d origine) et celui de la musique.
  void _volumes({int? origine, int? musique}) {
    final m = _musique;
    _lecteur?.setVolume(!_son ? 0 : (origine ?? m?.volumeOrigine ?? 100) / 100);
    _audio?.setVolume((musique ?? m?.volume ?? 100) / 100);
  }

  // La musique choisie joue avec la video, depuis son extrait.
  Future<void> _jouerMusique() async {
    final m = _musique;
    if (m == null) {
      await _audio?.stop();
      _volumes();
      return;
    }
    final audio = _audio ??= AudioPlayer();
    try {
      await audio.setUrl(m.son.url);
      await audio.seek(Duration(milliseconds: m.debutMs));
      _volumes();
      await _lecteur?.seekTo(Duration.zero);
      _derniere = Duration.zero;
      if (_lecteur?.value.isPlaying ?? false) unawaited(audio.play());
    } catch (_) {
      if (mounted) bulle(context, t('Impossible de lire ce son. Vérifiez la connexion.'), icone: 'hors-ligne');
    }
  }

  Future<void> _choisirSon() async {
    await _audio?.pause();
    if (!mounted) return;
    final s = await choisirSon(context);
    if (s == null || !mounted) {
      if (_lecteur?.value.isPlaying ?? false) unawaited(_audio?.play());
      return;
    }
    setState(() => _musique = MusiqueChoisie(s, debutMs: s.debutConseilleMs));
    await _jouerMusique();
  }

  void _retirerSon() {
    setState(() => _musique = null);
    musiqueDuReel = null;
    _jouerMusique();
  }

  Future<void> _extrait() async {
    final m = _musique;
    if (m == null) return;
    await _audio?.pause();
    if (!mounted) return;
    final debut = await choisirExtrait(context, m, dureeReelMs: (_sequence?.$2 ?? 15) * 1000);
    if (debut != null) setState(() => _musique = m.copie(debutMs: debut));
    await _jouerMusique();
  }

  Future<void> _reglerVolumes() async {
    final m = _musique;
    if (m == null) return;
    final r = await reglerVolumes(
      context,
      m,
      sonOrigine: _son,
      enDirect: (o, v) => _volumes(origine: o, musique: v),
    );
    if (r != null) setState(() => _musique = r);
    _volumes();
  }

  Future<void> _charger() async {
    final ancien = _lecteur;
    final lecteur = VideoPlayerController.file(File(_sequence!.$1));
    _lecteur = lecteur;
    setState(() {});
    ancien?.removeListener(_suivreLecture);
    await ancien?.dispose();
    try {
      await lecteur.initialize();
      await lecteur.setLooping(true);
      await lecteur.setVolume(_son ? 1 : 0);
      await lecteur.play();
      lecteur.addListener(_suivreLecture);
      if (_musique != null) await _jouerMusique();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  String _temps(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // Couper : le debut et la fin, de 1 a 60 secondes. Android recopie ce morceau sans le reencoder.
  Future<void> _couper() async {
    final lecteur = _lecteur;
    if (lecteur == null || !lecteur.value.isInitialized) return;
    final total = lecteur.value.duration.inMilliseconds / 1000;
    if (total <= 1) return bulle(context, t('Cette séquence est trop courte pour être coupée.'));
    var choix = RangeValues(0, total.clamp(1, 60).toDouble());
    final garder = await montrerFeuille<RangeValues>(
      context,
      titre: t('Couper'),
      contenu: (f) => StatefulBuilder(
        builder: (context, maj) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_temps(Duration(milliseconds: (choix.start * 1000).round()))} – ${_temps(Duration(milliseconds: (choix.end * 1000).round()))} · ${(choix.end - choix.start).round()} s',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              RangeSlider(
                values: choix,
                max: total,
                activeColor: Couleurs.texte,
                onChanged: (v) {
                  // De 1 à 60 secondes.
                  if (v.end - v.start < 1 || v.end - v.start > 60) return;
                  maj(() => choix = v);
                  lecteur.seekTo(Duration(milliseconds: (v.start * 1000).round()));
                },
              ),
              Text(t('Un reel dure de 1 à 60 secondes.'), textAlign: TextAlign.center, style: Textes.petit),
              const SizedBox(height: 14),
              BoutonVerre(texte: t('Appliquer'), plein: true, onTap: () => Navigator.pop(f, choix)),
            ],
          ),
        ),
      ),
    );
    if (garder == null || !mounted) return;
    if (garder.start < 0.05 && garder.end > total - 0.05) return;
    setState(() => _travail = true);
    final coupee = await Appareil.couper(
      _sequence!.$1,
      Duration(milliseconds: (garder.end * 1000).round()),
      debut: Duration(milliseconds: (garder.start * 1000).round()),
    );
    if (!mounted) return;
    setState(() => _travail = false);
    if (coupee == null) return bulle(context, t('Impossible de couper cette vidéo.'), icone: 'alerte');
    _sequence = (coupee, (garder.end - garder.start).round().clamp(1, 60));
    await _charger();
  }

  void _basculerSon() {
    setState(() => _son = !_son);
    _volumes();
    bulle(context, _son ? t('Son d’origine activé.') : t('Son d’origine coupé.'), icone: _son ? 'son' : 'muet');
  }

  // Suivant : le reel part avec ce telephone, l heure et la position (sans son, si on l a coupe).
  Future<void> _suivant() async {
    var sequence = _sequence;
    if (sequence == null || _travail) return;
    if (!_son) {
      setState(() => _travail = true);
      final muette = await Appareil.couper(sequence.$1, Duration(seconds: sequence.$2 + 1), son: false);
      if (!mounted) return;
      setState(() => _travail = false);
      if (muette == null) return bulle(context, t('Impossible de couper le son de cette vidéo.'), icone: 'alerte');
      sequence = (muette, sequence.$2);
    }
    sequencesDuReel
      ..clear()
      ..add(sequence);
    // La musique part avec le reel ; le son d origine coupe compte pour zero.
    final m = _musique;
    musiqueDuReel = m == null ? null : (_son ? m : m.copie(volumeOrigine: 0));
    // La video du montage s arrete sous l ecran suivant : la musique la suit, elle se tait aussi.
    await _lecteur?.pause();
    await _audio?.pause();
    Capture.courante ??= await lireCapture(sequence.$1, video: true, priseAvecUsw: true);
    final c = Capture.courante;
    if (!mounted) return;
    // Ce que la video ne dit pas (une video de la galerie) se complete d abord.
    await context.push(c == null || c.verifiee ? '/creer/details?reel=1' : '/creer/completer');
    // Retour au montage : la video (et sa musique) reprend.
    if (mounted) unawaited(_lecteur?.play());
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final bas = MediaQuery.paddingOf(context).bottom;
    final sequence = _sequence;
    // Rien de tourne (un lien direct) : rien a monter.
    if (sequence == null) return const EcranEtat(etat: 'introuvable');
    final lecteur = _lecteur;
    final pret = lecteur != null && lecteur.value.isInitialized;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: barreSombre,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D14),
        body: Padding(
          padding: EdgeInsets.fromLTRB(14, haut + 8, 14, bas + 14),
          child: Column(
            children: [
              Row(
                children: [
                  RondVerre(icone: 'retour', semantique: t('Retour'), surPhoto: true, encre: Colors.white, onTap: () => context.pop()),
                  Expanded(
                    child: Text(
                      t('Monter le reel'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  BoutonVerre(texte: t('Suivant'), plein: true, large: false, enCours: _travail, onTap: _travail ? null : _suivant),
                ],
              ),
              const SizedBox(height: 10),
              // Le son choisi, comme en haut de TikTok : le toucher pour en changer, la croix pour le retirer.
              _PastilleSon(musique: _musique, onTap: _travail ? null : _choisirSon, onRetirer: _retirerSon),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (pret)
                            GestureDetector(
                              onTap: () => setState(() => lecteur.value.isPlaying ? lecteur.pause() : lecteur.play()),
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(width: lecteur.value.size.width, height: lecteur.value.size.height, child: VideoPlayer(lecteur)),
                              ),
                            )
                          else
                            const ColoredBox(color: Colors.black),
                          if (pret && !lecteur.value.isPlaying)
                            IgnorePointer(
                              child: Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                                  child: const Icone('lecture', taille: 28, couleur: Colors.white),
                                ),
                              ),
                            ),
                          if (pret)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Text(
                                '${_temps(lecteur.value.position)} / ${_temps(lecteur.value.duration)}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          if (!_son) const Positioned(left: 10, bottom: 10, child: Icone('muet', taille: 16, couleur: Colors.white)),
                          if (_travail) const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Outil(icone: 'ciseaux', nom: t('Couper'), onTap: pret && !_travail ? _couper : null),
                  _Outil(icone: 'musique', nom: t('Son'), onTap: _travail ? null : _choisirSon),
                  if (_musique != null) ...[
                    _Outil(icone: 'horloge', nom: t('Extrait'), onTap: _travail ? null : _extrait),
                    _Outil(icone: 'filtres', nom: t('Volume'), onTap: _travail ? null : _reglerVolumes),
                  ],
                  _Outil(icone: _son ? 'son' : 'muet', nom: _son ? t('Son activé') : t('Son coupé'), onTap: _travail ? null : _basculerSon),
                ],
              ),
              const SizedBox(height: 16),
              // La sequence et ou en est la lecture.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pret && lecteur.value.duration.inMilliseconds > 0 ? lecteur.value.position.inMilliseconds / lecteur.value.duration.inMilliseconds : 0,
                  minHeight: 4,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${sequence.$2} s',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En haut du montage : « Ajouter un son », ou le son choisi (titre et artiste) avec sa croix.
class _PastilleSon extends StatelessWidget {
  const _PastilleSon({required this.musique, required this.onTap, required this.onRetirer});

  final MusiqueChoisie? musique;
  final VoidCallback? onTap;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final m = musique;
    const blanc = Colors.white;
    return Center(
      child: Appuyable(
        onTap: onTap,
        semantique: m == null ? t('Ajouter un son') : t('Changer de son'),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          height: 36,
          padding: EdgeInsets.only(left: 14, right: m == null ? 14 : 4),
          decoration: BoxDecoration(color: blanc.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icone('musique', taille: 16, couleur: blanc),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  m == null ? t('Ajouter un son') : m.son.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: blanc),
                ),
              ),
              if (m != null)
                Appuyable(
                  onTap: onRetirer,
                  semantique: t('Retirer le son'),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icone('fermer', taille: 16, couleur: blanc),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Outil extends StatelessWidget {
  const _Outil({required this.icone, required this.nom, required this.onTap});

  final String icone;
  final String nom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const couleur = Colors.white;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Column(
        children: [
          RondVerre(icone: icone, semantique: nom, surPhoto: true, encre: couleur, onTap: onTap),
          const SizedBox(height: 5),
          Text(nom, style: const TextStyle(fontSize: 12, color: couleur)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ E15 ce que le fichier ne dit pas

class EcranCompleterInfos extends StatefulWidget {
  const EcranCompleterInfos({super.key, this.lot = false});

  /// Un fichier du lot : on y revient, sans passer par les details.
  final bool lot;

  @override
  State<EcranCompleterInfos> createState() => _EcranCompleterInfosState();
}

class _EcranCompleterInfosState extends State<EcranCompleterInfos> {
  final _capture = Capture.courante;
  late final _modele = TextEditingController(text: _capture?.modele ?? '');
  // La date de la prise : lue dans le fichier, sinon choisie dans le calendrier (jamais apres aujourd hui).
  late DateTime? _datePrise = _capture?.date ?? _capture?.dateDeclaree;
  late String? _telephone = _capture?.modele;
  late ChoixLieu? _choix = _capture?.lieuChoisi;

  // Le lieu choisi, sinon celui de la prise ; nul si la photo n en dit rien.
  String? get _lieu => _choix?.affiche ?? (_capture?.latitude != null ? _capture!.lieu : null);
  String _ceTelephone = 'Ce téléphone';

  @override
  void initState() {
    super.initState();
    modeleDuTelephone().then((m) {
      if (mounted) setState(() => _ceTelephone = m);
    });
  }

  // Le lieu manque : la localisation coupee, la permission refusee, ou un fichier sans GPS.
  String get _sansLieu => switch (_capture?.priseAvecUsw == true ? positionManquee : null) {
    SansPosition.coupee => t('Localisation désactivée sur le téléphone'),
    SansPosition.refusee => t('Discover n’a pas accès à la position'),
    SansPosition.introuvable => t('Position introuvable'),
    null => t('Aucune position dans le fichier'),
  };

  // Ce qui manque, en une phrase.
  String get _manque {
    final c = _capture;
    if (c == null) return t('Cette photo ancienne n’a ni téléphone ni date.');
    final telephone = c.modele == null, date = c.date == null;
    if (c.video) {
      if (telephone && date) return t('Cette vidéo n’indique ni le téléphone ni la date.');
      if (telephone) return t('Cette vidéo n’indique pas le téléphone.');
      if (date) return t('Cette vidéo n’indique pas la date.');
      return t('Cette vidéo indique déjà le téléphone et la date.');
    }
    if (telephone && date) return t('Cette photo n’indique ni le téléphone ni la date.');
    if (telephone) return t('Cette photo n’indique pas le téléphone.');
    if (date) return t('Cette photo n’indique pas la date.');
    return t('Cette photo indique déjà le téléphone et la date.');
  }

  // Rien ne manque : un fichier du lot ouvert pour changer son lieu.
  bool get _complet => _capture != null && _capture.modele != null && _capture.date != null;

  void _continuer() {
    final c = _capture;
    if (c != null) {
      // Ce qui est indique a la main rend la publication « declaree ».
      final dateChangee = c.date != null && _datePrise != c.date;
      c.declaree = c.declaree || c.modele == null || c.date == null || dateChangee || _telephone != c.modele;
      c.modele = _telephone;
      if (dateChangee) c.date = null;
      if (c.date == null) c.dateDeclaree = _datePrise;
      if (_choix != null) c.lieuChoisi = _choix;
    }
    if (widget.lot) {
      context.pop();
      return;
    }
    context.push('/creer/details?declare=1');
  }

  // Le calendrier s arrete a aujourd hui : une date future ne peut pas etre choisie.
  Future<void> _choisirDate() async {
    final aujourdhui = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _datePrise != null && !_datePrise!.isAfter(aujourdhui) ? _datePrise! : aujourdhui,
      firstDate: DateTime(1990),
      lastDate: aujourdhui,
      helpText: t('Date de la prise'),
      cancelText: t('Annuler'),
      confirmText: t('OK'),
    );
    if (d != null && mounted) setState(() => _datePrise = DateTime(d.year, d.month, d.day, 12));
  }

  // Comme le serveur (ModeleTelephone::normaliser) : sans accents, majuscules ni ponctuation.
  static String _nomSimple(String t) => texteSimple(t).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  // Les telephones deja sur Discover qui ressemblent a ce qui est tape (le serveur).
  List<String> _connus = const [];
  Timer? _attenteModeles;

  void _chercherModeles() {
    _attenteModeles?.cancel();
    final q = _modele.text.trim();
    if (q.length < 2) return;
    _attenteModeles = Timer(const Duration(milliseconds: 300), () async {
      final trouves = await Catalogue.instance.modelesTelephone(q);
      if (mounted && _modele.text.trim() == q) setState(() => _connus = trouves);
    });
  }

  @override
  void dispose() {
    _attenteModeles?.cancel();
    _modele.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saisie = _modele.text.trim();
    final proches = saisie.length < 2 ? const <String>[] : _connus.take(3).toList();
    // Le serveur range un telephone par sa marque et son modele : il faut les deux.
    final marqueEtModele = saisie.contains(' ');
    final pret = _telephone != null && _datePrise != null;
    return PageFormulaire(
      centre: false,
      enfants: [
        const SizedBox(height: 10),
        Titre(widget.lot && _complet ? t('Cette publication') : t('Ce que le fichier ne dit pas'), style: Textes.titre),
        const SizedBox(height: 10),
        Text(widget.lot && _complet ? _manque : '$_manque ${t('Ajoutez ces informations. La publication portera le badge « Informations déclarées ».')}', style: Textes.discret),
        const SizedBox(height: 22),
        ChampVerre(
          libelle: t("Le téléphone qui l'a prise"),
          icone: 'telephone',
          indice: t('La marque et le modèle'),
          controleur: _modele,
          aide: Text(t("Choisissez-le s'il est dans la liste, sinon ajoutez-le.")),
          onChanged: (_) {
            setState(() => _telephone = null);
            _chercherModeles();
          },
        ),
        if (_telephone == null && saisie.length >= 2) ...[
          const SizedBox(height: 8),
          Plaque(
            child: Column(
              children: [
                if (!_connus.any((m) => _nomSimple(m) == _nomSimple(saisie)))
                  marqueEtModele
                      ? ListTile(
                          leading: Icone('plus', taille: 22, couleur: Couleurs.texte),
                          title: Text(t('Ajouter « {nom} »', {'nom': saisie}), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(t('Il rejoindra la liste pour les suivants')),
                          onTap: () => setState(() => _telephone = saisie),
                        )
                      : ListTile(
                          leading: Icone('telephone', taille: 22, couleur: Couleurs.discret),
                          title: Text(t('Indiquez la marque et le modèle')),
                          subtitle: Text(t('Par exemple Google Pixel 8')),
                        ),
                for (final m in proches)
                  ListTile(
                    leading: Icone('telephone', taille: 22),
                    title: Text(m),
                    subtitle: Text(t('Déjà utilisé sur Discover')),
                    onTap: () => setState(() {
                      _telephone = m;
                      _modele.text = m;
                    }),
                  ),
              ],
            ),
          ),
        ],
        if (_telephone == null && _ceTelephone != 'Ce téléphone') ...[
          const SizedBox(height: 6),
          Lien(
            t('Utiliser ce téléphone : {modele}', {'modele': _ceTelephone}),
            onTap: () => setState(() {
              _telephone = _ceTelephone;
              _modele.text = _telephone!;
            }),
          ),
        ],
        const SizedBox(height: 16),
        Text(t('Date de la prise'), style: Textes.libelle),
        const SizedBox(height: 8),
        Appuyable(
          semantique: t('Choisir la date de la prise'),
          onTap: _choisirDate,
          child: Verre(
            rayon: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icone('calendrier', taille: 21, couleur: Couleurs.texte),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_datePrise == null ? t('Choisir une date') : jourLisible(_datePrise!), style: TextStyle(fontSize: 15.5, color: _datePrise == null ? Couleurs.discret : Couleurs.texte)),
                ),
                Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(t('Le lieu'), style: Textes.libelle),
        const SizedBox(height: 8),
        Appuyable(
          semantique: t('Indiquer le lieu'),
          onTap: () async {
            final l = await context.push<ChoixLieu>('/creer/lieu');
            if (l != null) setState(() => _choix = l);
          },
          child: Verre(
            child: SizedBox(
              height: 54,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icone('lieu', taille: 22, couleur: _lieu == null ? Couleurs.discret : null),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_lieu == null ? _sansLieu : _vu(_lieu!), style: TextStyle(fontSize: 16, color: _lieu == null ? Couleurs.discret : Couleurs.texte)),
                    ),
                    Text(_lieu == null ? t('Indiquer') : t('Changer'), style: Textes.lien.copyWith(color: Couleurs.texte)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(t('Badge de la publication'), style: Textes.petit),
            const SizedBox(width: 10),
            BadgeCapture(verifie: widget.lot && _complet && _capture?.declaree != true && _capture?.verifiee == true),
          ],
        ),
      ],
      pied: BoutonVerre(texte: widget.lot ? t('Garder') : t('Continuer'), plein: true, onTap: pret ? _continuer : null),
    );
  }
}

// ------------------------------------------------------------ E14 details

class EcranDetails extends StatefulWidget {
  const EcranDetails({super.key, this.reel = false, this.declaree = false});

  final bool reel;
  final bool declaree;

  @override
  State<EcranDetails> createState() => _EcranDetailsState();
}

class _EcranDetailsState extends State<EcranDetails> {
  // La capture du telephone (nulle sur un lien direct : rien a publier).
  final _capture = Capture.courante;
  final _legende = TextEditingController();
  late ChoixLieu? _choix = _capture?.lieuChoisi;

  String get _lieu => _choix?.affiche ?? (_capture?.lieu ?? 'Sans lieu');

  bool get _verifiee => !widget.declaree && (_capture?.verifiee ?? true);
  bool get _video => widget.reel || (_capture?.video ?? false);

  @override
  void dispose() {
    _legende.dispose();
    super.dispose();
  }

  String get _photo => _capture != null && !_capture.video ? _capture.chemin : (_capture?.vignette ?? '');

  void _publier({bool brouillon = false}) {
    final c = _capture;
    if (c == null || (c.video ? c.vignette : c.chemin) == null) {
      bulle(context, t('Prenez ou choisissez d’abord une photo.'), icone: 'camera');
      return;
    }
    c.lieuChoisi = _choix;
    lancerPublication(
      c,
      legende: _legende.text.trim(),
      declaree: widget.declaree,
      video: c.video ? (sequencesDuReel.isNotEmpty ? sequencesDuReel.first.$1 : c.chemin) : null,
      duree: c.video ? (sequencesDuReel.isNotEmpty ? sequencesDuReel.first.$2 : 1) : null,
      brouillon: brouillon,
    )?.ignore();
    Capture.courante = null;
    if (pourMonLifestyle) {
      context.go('/profil/lifestyle');
      bulle(context, brouillon ? t('Gardé dans vos brouillons.') : t('Publication lancée dans votre lifestyle.'), icone: brouillon ? 'crayon' : null);
      return;
    }
    // On retrouve la publication la ou elle est : un reel (tourne avec Discover) dans les Reels, le reste a l accueil.
    context.go(c.video && c.priseAvecUsw ? '/reels' : '/accueil');
    bulle(context, t('Publication lancée : vous pouvez continuer à naviguer.'));
  }

  @override
  Widget build(BuildContext context) => PageFormulaire(
    centre: false,
    titre: t('Nouvelle publication'),
    enfants: [
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            height: _video ? 200 : 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_capture?.video ?? false)
                  _capture!.vignette != null
                      ? PhotoArrondie(_capture.vignette!, rayon: 16)
                      : DecoratedBox(
                          decoration: BoxDecoration(color: Couleurs.hsl(229, 20, 14), borderRadius: BorderRadius.circular(16)),
                          child: const Center(child: Icone('lecture', taille: 34, couleur: Colors.white)),
                        )
                else
                  PhotoArrondie(_photo, rayon: 16),
                Positioned(left: 7, bottom: 7, child: BadgeCapture(verifie: _verifiee, seul: true)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgeCapture(verifie: _verifiee, court: true),
                const SizedBox(height: 12),
                for (final (icone, texte) in [
                  ('telephone', _capture?.modele ?? t('Téléphone inconnu')),
                  ('calendrier', _capture?.dateLisible ?? t('Date inconnue')),
                  ('lieu', _vu(_lieu.split(',').first)),
                ]) ...[
                  Row(
                    children: [
                      Icone(icone, taille: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(texte, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      ChampVerre(libelle: t('Légende'), icone: 'crayon', indice: t('Ce qu’on voit, ce qu’il faut savoir'), controleur: _legende, lignes: 3),
      const SizedBox(height: 16),
      Text(t('Lieu trouvé'), style: Textes.libelle),
      const SizedBox(height: 8),
      Appuyable(
        semantique: t('Changer le lieu'),
        onTap: () async {
          final l = await context.push<ChoixLieu>('/creer/lieu');
          if (l != null) setState(() => _choix = l);
        },
        child: Verre(
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icone('lieu', taille: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_vu(_lieu), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                  ),
                  Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
    pied: pourMonLifestyle
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BoutonVerre(texte: t('Publier dans mon lifestyle'), icone: 'envoyer', plein: true, onTap: _publier),
              const SizedBox(height: 10),
              BoutonVerre(texte: t('Garder en brouillon'), icone: 'crayon', onTap: () => _publier(brouillon: true)),
            ],
          )
        : BoutonVerre(texte: t('Publier'), icone: 'envoyer', plein: true, onTap: _publier),
  );
}

// ------------------------------------------------------------ publier une capture

// Le lieu connu de Discover a moins de 2 km de la prise, s il y en a un.
String? _lieuConnu(Capture c) {
  final lat = c.latitude, lon = c.longitude;
  if (lat == null || lon == null) return null;
  String? meilleur;
  var plusPres = 2000.0;
  for (final l in Catalogue.instance.lieux.where((l) => l.situe)) {
    final d = Geolocator.distanceBetween(lat, lon, l.latitude, l.longitude);
    if (d < plusPres) {
      plusPres = d;
      meilleur = l.id;
    }
  }
  return meilleur;
}

// Le poids du fichier, en Mo.
double _poidsMo(String chemin) {
  try {
    return File(chemin).lengthSync() / 1e6;
  } catch (_) {
    return 1;
  }
}

/// Publier une capture : sur mon profil tout de suite, comme sur les autres reseaux, puis
/// l envoi part (E16). `video` et `duree` : le fichier pret d une video et sa duree.
/// Nul s il n y a rien a montrer (une video sans couverture) ; sinon, la publication en route
/// (le lot les attend l une apres l autre, pour ne pas copier dix videos a la fois).
Future<void>? lancerPublication(Capture c, {required String legende, bool declaree = false, String? video, int? duree, bool brouillon = false}) {
  final couverture = c.video ? c.vignette : c.chemin;
  if (couverture == null) return null;
  final lieu = c.lieu;
  final titre = lieu.split(',').first;
  // Le lieu : celui choisi (un lieu de Discover, un point de la carte, un nom seul, aucun) ;
  // sinon celui de la prise (un lieu connu tout pres, sinon le nom donne par Android).
  final choix = c.lieuChoisi;
  final connu = choix != null ? choix.id : Catalogue.instance.lieux.where((l) => l.situe && l.nom == titre).firstOrNull?.id ?? _lieuConnu(c);
  final point = choix?.latitude != null && choix?.longitude != null;
  final a = choix?.adresse ?? c.adresse;
  final source = AEnvoyer(
    reel: c.video,
    original: video ?? c.chemin,
    image: couverture,
    duree: duree,
    legende: legende,
    lieuId: connu,
    lieuNom: connu == null && (choix == null || point) ? titre : null,
    lieuLatitude: point ? choix!.latitude : null,
    lieuLongitude: point ? choix!.longitude : null,
    nomLieu: choix != null && choix.nomSeul ? choix.nom : null,
    ville: a?.ville ?? '',
    region: a?.region ?? '',
    pays: a?.pays ?? '',
    paysCode: a?.code ?? '',
    latitude: c.latitude,
    longitude: c.longitude,
    priseLe: c.date ?? c.dateDeclaree,
    modele: c.modele,
    priseAvecDiscover: c.priseAvecUsw,
    modeleDeclare: declaree,
    dateDeclaree: c.date == null && c.dateDeclaree != null,
    // La musique du montage : seulement pour un reel filme avec Discover.
    musique: c.video && c.priseAvecUsw ? musiqueDuReel?.versServeur() : null,
    portee: pourMonLifestyle ? 'lifestyle' : null,
  );
  if (c.video) musiqueDuReel = null;
  // Pour mon lifestyle : il n a pas sa place a l accueil ni dans les Reels ; il part tel quel, ou
  // attend en brouillon.
  if (pourMonLifestyle) {
    final poids = _poidsMo(video ?? c.chemin);
    if (brouillon) return Lifestyle.instance.garderBrouillon(titre: titre, poidsMo: poids, source: source);
    Envois.instance.publier(titre: titre, photo: couverture, poidsMo: poids, source: source);
    return Future.value();
  }
  return MesPublications.instance
      .ajouter(
        photo: couverture,
        video: video,
        dureeReel: duree,
        lieu: lieu,
        legende: legende,
        appareil: c.modele ?? 'Ce téléphone',
        verifiee: !declaree && c.verifiee,
        priseAvecDiscover: c.priseAvecUsw,
        lieuId: connu,
        latitude: choix == null ? c.latitude : choix.latitude,
        longitude: choix == null ? c.longitude : choix.longitude,
      )
      .then((p) => Envois.instance.publier(titre: titre, photo: p.photo, poidsMo: _poidsMo(video ?? c.chemin), source: source, locale: p.photo))
      .catchError((Object _) {});
}

// ------------------------------------------------------------ le lot : plusieurs fichiers d un coup

/// Jusqu a 10 photos ou videos choisies d un coup : chacune devient une
/// publication, avec son telephone, sa date et son lieu. Ce qu un fichier ne
/// dit pas s indique en le touchant (E15). Chacun a sa legende ; la premiere peut
/// aller a toutes d un toucher.
class EcranLot extends StatefulWidget {
  const EcranLot({super.key});

  @override
  State<EcranLot> createState() => _EcranLotState();
}

class _EcranLotState extends State<EcranLot> {
  final _lot = List.of(Capture.lot);

  /// La legende de chaque fichier.
  final _legendes = <Capture, TextEditingController>{};

  TextEditingController _legendeDe(Capture c) => _legendes.putIfAbsent(c, () => TextEditingController()..addListener(_change));

  void _change() {
    if (mounted) setState(() {});
  }

  /// La premiere legende ecrite, a proposer aux autres fichiers encore sans legende.
  String? get _aPartager {
    final premiere = _lot.map((c) => _legendeDe(c).text.trim()).where((l) => l.isNotEmpty).firstOrNull;
    if (premiere == null || _lot.length < 2 || !_lot.any((c) => _legendeDe(c).text.trim().isEmpty)) return null;
    return premiere;
  }

  void _partager(String legende) {
    for (final c in _lot) {
      final l = _legendeDe(c);
      if (l.text.trim().isEmpty) l.text = legende;
    }
  }

  @override
  void dispose() {
    for (final l in _legendes.values) {
      l.dispose();
    }
    super.dispose();
  }

  static bool _complete(Capture c) => c.modele != null && (c.date != null || c.dateDeclaree != null);

  int get _aCompleter => _lot.where((c) => !_complete(c)).length;

  Future<void> _ouvrir(Capture c) async {
    Capture.courante = c;
    await context.push('/creer/completer?lot=1');
    Capture.courante = null;
    if (mounted) setState(() {});
  }

  // Le telephone indique pour un fichier, propose pour ceux qui ne le disent pas.
  String? get _telephoneIndique => _lot.where((c) => c.declaree && c.modele != null).firstOrNull?.modele;

  void _memeTelephone(String telephone) => setState(() {
    for (final c in _lot.where((c) => c.modele == null)) {
      c
        ..modele = telephone
        ..declaree = true;
    }
  });

  // Le lieu choisi pour un fichier, propose pour les autres (comme le telephone).
  ChoixLieu? get _lieuIndique {
    final choix = _lot.map((c) => c.lieuChoisi).nonNulls.firstOrNull;
    if (choix == null || _lot.every((c) => _memeLieu(c.lieuChoisi, choix))) return null;
    return choix;
  }

  static bool _memeLieu(ChoixLieu? a, ChoixLieu b) => a != null && a.nom == b.nom && a.id == b.id && a.latitude == b.latitude && a.longitude == b.longitude && a.nomSeul == b.nomSeul;

  void _memeLieuPourTous(ChoixLieu choix) => setState(() {
    for (final c in _lot) {
      c.lieuChoisi = choix;
    }
  });

  void _retirer(Capture c) {
    setState(() => _lot.remove(c));
    if (_lot.isEmpty) context.pop();
  }

  void _publier({bool brouillon = false}) {
    final lot = List.of(_lot);
    final legendes = {for (final c in lot) c: _legendeDe(c).text.trim()};
    // L une apres l autre, en arriere-plan : les copies ne se marchent pas dessus.
    () async {
      for (final c in lot) {
        await lancerPublication(c, legende: legendes[c] ?? '', declaree: c.declaree, video: c.video ? c.chemin : null, duree: c.video ? c.duree ?? 1 : null, brouillon: brouillon);
      }
    }().ignore();
    Capture.lot = [];
    if (pourMonLifestyle) {
      context.go('/profil/lifestyle');
      bulle(context, brouillon ? t('Gardé dans vos brouillons.') : tn(lot.length, 'Publication lancée dans votre lifestyle.', '{n} publications lancées dans votre lifestyle.'));
      return;
    }
    context.go('/accueil');
    bulle(context, tn(lot.length, 'Publication lancée : vous pouvez continuer à naviguer.', '{n} publications lancées : vous pouvez continuer à naviguer.'));
  }

  @override
  Widget build(BuildContext context) {
    final reste = _aCompleter;
    final telephone = _telephoneIndique;
    final aPartager = _aPartager;
    final lieu = _lieuIndique;
    return PageFormulaire(
      centre: false,
      titre: tn(_lot.length, 'Nouvelle publication', '{n} publications'),
      enfants: [
        const SizedBox(height: 10),
        Text(
          reste == 0
              ? t('Chaque fichier devient une publication, avec son téléphone, sa date et son lieu. Touchez-en un pour changer son lieu.')
              : t('Chaque fichier devient une publication. Touchez ceux qui ne disent pas tout pour l’indiquer : ils porteront le badge « Informations déclarées ».'),
          style: Textes.discret,
        ),
        const SizedBox(height: 16),
        Plaque(
          child: Column(
            children: [
              for (var i = 0; i < _lot.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 0.7, indent: 84, color: Couleurs.filet),
                _LigneLot(capture: _lot[i], complete: _complete(_lot[i]), onTap: () => _ouvrir(_lot[i]), onRetirer: () => _retirer(_lot[i])),
                // Sa legende a lui, sous sa ligne.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ChampVerre(libelle: t('Légende'), icone: 'crayon', indice: t('Facultatif'), controleur: _legendeDe(_lot[i]), lignes: 2),
                ),
              ],
            ],
          ),
        ),
        if (telephone != null && _lot.any((c) => c.modele == null)) ...[
          const SizedBox(height: 10),
          Lien(t('Utiliser le même téléphone pour les autres : {modele}', {'modele': telephone}), onTap: () => _memeTelephone(telephone)),
        ],
        if (lieu != null) ...[
          const SizedBox(height: 10),
          Lien(t('Mettre le même lieu sur les autres : {lieu}', {'lieu': _vu(lieu.affiche)}), onTap: () => _memeLieuPourTous(lieu)),
        ],
        if (aPartager != null) ...[
          const SizedBox(height: 10),
          Lien(t('Mettre « {legende} » sur les autres', {'legende': aPartager.length > 30 ? '${aPartager.substring(0, 30)}…' : aPartager}), onTap: () => _partager(aPartager)),
        ],
      ],
      pied: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BoutonVerre(
            texte: reste == 0
                ? (pourMonLifestyle ? t('Publier dans mon lifestyle') : (_lot.length == 1 ? t('Publier') : t('Publier les {n}', {'n': _lot.length})))
                : tn(reste, 'Encore {n} à compléter', 'Encore {n} à compléter'),
            icone: reste == 0 ? 'envoyer' : null,
            plein: true,
            onTap: reste == 0 ? _publier : null,
          ),
          if (pourMonLifestyle && reste == 0) ...[const SizedBox(height: 10), BoutonVerre(texte: t('Garder en brouillon'), icone: 'crayon', onTap: () => _publier(brouillon: true))],
        ],
      ),
    );
  }
}

class _LigneLot extends StatelessWidget {
  const _LigneLot({required this.capture, required this.complete, required this.onTap, required this.onRetirer});

  final Capture capture;
  final bool complete;
  final VoidCallback onTap;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final c = capture;
    final image = c.video ? c.vignette : c.chemin;
    final sansTelephone = c.modele == null, sansDate = c.date == null && c.dateDeclaree == null;
    final detail = complete
        ? [c.modele, c.dateLisible].whereType<String>().join(' · ')
        : sansTelephone && sansDate
        ? t('À compléter : le téléphone et la date')
        : sansTelephone
        ? t('À compléter : le téléphone')
        : t('À compléter : la date');
    final lieu = _vu(c.lieu.split(',').first);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              // L image et le texte se lisent ensemble ; « Retirer » reste un bouton a part.
              Expanded(
                child: Semantics(
                  button: true,
                  label: c.video ? t('Vidéo, {lieu}, {detail}', {'lieu': lieu, 'detail': detail}) : t('Photo, {lieu}, {detail}', {'lieu': lieu, 'detail': detail}),
                  onTap: onTap,
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (image != null)
                              PhotoArrondie(image, rayon: 10)
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(color: Couleurs.photoVide, borderRadius: BorderRadius.circular(10)),
                              ),
                            if (c.video) const Center(child: Icone('lecture', taille: 20, couleur: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lieu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Textes.petit.copyWith(color: complete ? Couleurs.discret : Couleurs.erreur),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onRetirer,
                tooltip: t('Retirer'),
                icon: Icone('fermer', taille: 18, couleur: Couleurs.discret),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ E30 choisir le lieu

/// Le lieu d une publication : le chercher par son nom (les lieux de Discover,
/// puis ceux de Google, avec leur position exacte), ou poser l epingle sur la
/// carte ; ou ne donner qu un nom, sans position ; ou aucun lieu.
class EcranChoisirLieu extends StatefulWidget {
  const EcranChoisirLieu({super.key});

  @override
  State<EcranChoisirLieu> createState() => _EcranChoisirLieuState();
}

class _EcranChoisirLieuState extends State<EcranChoisirLieu> {
  /// Un lieu de Discover a moins de 300 m de l epingle : c est lui.
  static const _rayonMetres = 300.0;

  GoogleMapController? _carte;

  // La carte part de la position de la prise, sinon de Cotonou.
  late LatLng _centre = Capture.courante?.latitude != null ? LatLng(Capture.courante!.latitude!, Capture.courante!.longitude!) : const LatLng(6.3703, 2.3912);
  late final double _zoomDepart = Capture.courante?.latitude != null ? 15 : 12;
  bool _bouge = false;

  final _recherche = TextEditingController();
  final _focus = FocusNode();
  final _nom = TextEditingController();
  Timer? _attente;
  int _demande = 0;
  bool _cherche = false;
  bool _ouvreGoogle = false;
  ({List<Lieu> lieux, List<({String id, String nom, String adresse})> google})? _resultats;

  /// Le lieu touche dans la recherche : la carte y va, l epingle s y pose.
  Lieu? _trouve;

  /// La ville et le pays du point, lus par Android.
  Adresse? _adresse;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _lireAdresse();
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    _focus.dispose();
    _nom.dispose();
    super.dispose();
  }

  double _metres(Lieu l) => Geolocator.distanceBetween(_centre.latitude, _centre.longitude, l.latitude, l.longitude);

  /// Le lieu de Discover sous l epingle : celui de la recherche, sinon le plus proche a moins de 300 m.
  Lieu? get _sousEpingle {
    final t = _trouve;
    if (t != null) return t;
    Lieu? proche;
    var mieux = _rayonMetres;
    for (final l in Catalogue.instance.lieux.where((l) => l.situe)) {
      final d = _metres(l);
      if (d < mieux) {
        mieux = d;
        proche = l;
      }
    }
    return proche;
  }

  Future<void> _lireAdresse() async {
    final point = _centre;
    final a = await Appareil.adresse(point.latitude, point.longitude);
    if (mounted && point == _centre) setState(() => _adresse = a);
  }

  void _taper(String texte) {
    _attente?.cancel();
    setState(() {});
    if (texte.trim().length < 2) {
      setState(() => _resultats = null);
      return;
    }
    _attente = Timer(const Duration(milliseconds: 350), () => _chercher(texte));
  }

  Future<void> _chercher(String texte) async {
    final demande = ++_demande;
    setState(() => _cherche = true);
    final r = await Catalogue.instance.suggestionsLieu(texte, latitude: _centre.latitude, longitude: _centre.longitude);
    if (!mounted || demande != _demande) return;
    setState(() {
      _cherche = false;
      _resultats = r;
    });
  }

  void _allerA(Lieu l) {
    _focus.unfocus();
    setState(() {
      _trouve = l;
      _centre = LatLng(l.latitude, l.longitude);
      _recherche.clear();
      _resultats = null;
    });
    _carte?.animateCamera(CameraUpdate.newLatLngZoom(_centre, 16));
  }

  Future<void> _google(String id) async {
    setState(() => _ouvreGoogle = true);
    final l = await Catalogue.instance.lieuGoogle(id);
    if (!mounted) return;
    setState(() => _ouvreGoogle = false);
    if (l == null) {
      bulle(context, t('Ce lieu est introuvable. Placez l’épingle sur la carte.'), icone: 'lieu');
      return;
    }
    _allerA(l);
  }

  // Le point choisi : le lieu de Discover sous l epingle, sinon un nouveau lieu a ce point, avec son nom.
  void _choisir() {
    final l = _sousEpingle;
    if (l != null) {
      context.pop(ChoixLieu(nom: l.nom, id: l.id));
      return;
    }
    final nom = _nom.text.trim().isNotEmpty ? _nom.text.trim() : (_adresse?.court ?? '');
    if (nom.isEmpty) {
      bulle(context, t('Donnez un nom à ce lieu.'), icone: 'crayon');
      return;
    }
    context.pop(ChoixLieu(nom: nom, latitude: _centre.latitude, longitude: _centre.longitude, adresse: _adresse));
  }

  // Un nom seul : les autres le lisent, sans savoir ou c est.
  Future<void> _nomSeul([String depart = '']) async {
    final champ = TextEditingController(text: depart);
    final nom = await montrerFeuille<String>(
      context,
      titre: t('Juste un nom'),
      contenu: (f) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(f).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('Le nom s’affiche sous la photo. Sa position reste privée et n’apparaît pas sur la carte.'), style: Textes.discret),
            const SizedBox(height: 16),
            ChampVerre(icone: 'crayon', indice: t('Chez ma grand-mère, le marché du village…'), controleur: champ, action: TextInputAction.done),
            const SizedBox(height: 16),
            BoutonVerre(texte: t('Garder ce nom'), plein: true, onTap: () => Navigator.pop(f, champ.text.trim())),
          ],
        ),
      ),
    );
    champ.dispose();
    if (!mounted || nom == null || nom.isEmpty) return;
    context.pop(ChoixLieu(nom: nom, nomSeul: true));
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final bas = MediaQuery.paddingOf(context).bottom;
    final ici = _sousEpingle;
    final texte = _recherche.text.trim();
    final liste = _focus.hasFocus && texte.length >= 2;
    String c(double v) => v.abs().toStringAsFixed(4).replaceAll('.', ',');
    final lat = _centre.latitude, lon = _centre.longitude;
    final latitude = lat >= 0 ? t('{v}° N', {'v': c(lat)}) : t('{v}° S', {'v': c(lat)});
    final longitude = lon >= 0 ? t('{v}° E', {'v': c(lon)}) : t('{v}° O', {'v': c(lon)});
    final gps = '$latitude, $longitude';
    return Scaffold(
      body: Stack(
        children: [
          // L epingle est au centre de l ecran : la carte garde le meme centre.
          CarteGoogle(
            centre: _centre,
            zoom: _zoomDepart,
            onCree: (carte) => _carte = carte,
            onDebut: () => setState(() => _bouge = true),
            onBouge: (camera) => setState(() => _centre = camera.target),
            onArret: () {
              setState(() {
                _bouge = false;
                // L epingle a quitte le lieu trouve : c est un autre point.
                if (_trouve != null && _metres(_trouve!) > _rayonMetres) _trouve = null;
              });
              _lireAdresse();
            },
          ),
          // L epingle reste au centre ; elle se souleve quand la carte bouge.
          IgnorePointer(
            child: Center(
              child: AnimatedSlide(duration: const Duration(milliseconds: 380), curve: Courbes.ressort, offset: Offset(0, _bouge ? -0.75 : -0.5), child: const Icone('epingle', taille: 46)),
            ),
          ),
          Positioned(
            top: haut + 8,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
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
                                  controller: _recherche,
                                  focusNode: _focus,
                                  onChanged: _taper,
                                  textInputAction: TextInputAction.search,
                                  style: TextStyle(fontSize: 15.5, color: Couleurs.texte),
                                  decoration: InputDecoration.collapsed(
                                    hintText: t('Rechercher un lieu : IFRI, Grand-Popo…'),
                                    hintStyle: TextStyle(fontSize: 15.5, color: Couleurs.discret),
                                  ),
                                ),
                              ),
                              if (_cherche || _ouvreGoogle)
                                Padding(padding: const EdgeInsets.only(right: 14), child: const LogoQuiTourne(taille: 18))
                              else if (texte.isNotEmpty)
                                IconButton(
                                  tooltip: t('Effacer'),
                                  icon: Icone('fermer', taille: 18, couleur: Couleurs.discret),
                                  onPressed: () => setState(() {
                                    _recherche.clear();
                                    _resultats = null;
                                  }),
                                )
                              else
                                const SizedBox(width: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (liste) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                    child: Plaque(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: [
                          for (final l in _resultats?.lieux ?? const <Lieu>[])
                            ListTile(
                              leading: const Icone('lieu', taille: 22),
                              title: Text(l.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(l.region.isEmpty ? t('Sur Discover') : t('{region} · sur Discover', {'region': l.region})),
                              onTap: () => _allerA(l),
                            ),
                          for (final g in _resultats?.google ?? const <({String id, String nom, String adresse})>[])
                            ListTile(
                              leading: Icone('epingle', taille: 22, couleur: Couleurs.discret),
                              title: Text(g.nom),
                              subtitle: g.adresse.isEmpty ? null : Text(g.adresse),
                              onTap: () => _google(g.id),
                            ),
                          ListTile(
                            leading: Icone('crayon', taille: 22, couleur: Couleurs.discret),
                            title: Text(t('« {nom} », sans position', {'nom': texte})),
                            subtitle: Text(t('Juste le nom, pas sur la carte')),
                            onTap: () => _nomSeul(texte),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!_focus.hasFocus)
            Positioned(
              left: 14,
              right: 14,
              bottom: bas + 14,
              child: Verre(
                rayon: 26,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ici != null ? t('Ce lieu est sur Discover.') : t("Recherchez le lieu ou déplacez la carte pour placer l'épingle."), style: Textes.petit),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icone('lieu', taille: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ici != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ici.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    Text(ici.region.isEmpty ? gps : '${ici.region} · $gps', style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _nom,
                                      textCapitalization: TextCapitalization.sentences,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Couleurs.texte),
                                      decoration: InputDecoration.collapsed(
                                        hintText: _adresse?.court.isNotEmpty == true ? _adresse!.court : t('Nom de ce lieu'),
                                        hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Couleurs.discret),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(t('Nouveau lieu · {gps}', {'gps': gps}), style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                                  ],
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    BoutonVerre(texte: t('Choisir ce lieu'), plein: true, onTap: _choisir),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Lien(t('Juste un nom'), onTap: _nomSeul),
                        Lien(t('Sans lieu'), discret: true, onTap: () => context.pop(ChoixLieu.aucun)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ E26 mes envois

class EcranEnvois extends StatefulWidget {
  const EcranEnvois({super.key});

  @override
  State<EcranEnvois> createState() => _EcranEnvoisState();
}

class _EcranEnvoisState extends State<EcranEnvois> {
  Timer? _relance;

  @override
  void initState() {
    super.initState();
    // Les decisions attendues se redemandent a l ouverture, puis toutes les 30 s tant
    // qu une analyse tourne et que la page reste ouverte.
    Envois.instance.actualiser();
    Telechargements.instance.charger();
    _relance = Timer.periodic(const Duration(seconds: 30), (_) {
      if (Envois.instance.liste.any((e) => e.etat == EtatEnvoi.verification && e.attente == null)) Envois.instance.actualiser();
    });
  }

  @override
  void dispose() {
    _relance?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([Envois.instance, Telechargements.instance]),
        builder: (context, _) {
          final liste = Envois.instance.liste;
          final telecharges = Telechargements.instance.liste;
          Widget groupe(String titre, Iterable<Envoi> envois) => envois.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
                      child: Text(
                        titre,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
                      ),
                    ),
                    for (final e in envois) _LigneEnvoi(envoi: e),
                    const SizedBox(height: 10),
                  ],
                );
          return ListView(
            padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 40 + MediaQuery.paddingOf(context).bottom),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              ),
              const SizedBox(height: 14),
              Titre(t('Mes envois'), style: Textes.titre),
              const SizedBox(height: 8),
              Text(t("Un envoi interrompu reprend là où il s'était arrêté dès que le réseau revient."), style: Textes.discret),
              const SizedBox(height: 18),
              groupe(t('En cours'), liste.where((e) => e.etat == EtatEnvoi.encours || e.etat == EtatEnvoi.pause)),
              groupe(t('En vérification'), liste.where((e) => e.etat == EtatEnvoi.verification)),
              groupe(t('Terminés'), liste.where((e) => e.etat == EtatEnvoi.publie || e.etat == EtatEnvoi.refuse)),
              if (telecharges.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
                  child: Text(
                    t('Téléchargements'),
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
                  ),
                ),
                for (final d in telecharges) _LigneTelechargement(telecharge: d),
              ],
              if (liste.isEmpty && telecharges.isEmpty) Text(t('Rien pour le moment.'), style: Textes.discret),
            ],
          );
        },
      ),
    );
  }
}

class _LigneEnvoi extends StatelessWidget {
  const _LigneEnvoi({required this.envoi});

  final Envoi envoi;

  @override
  Widget build(BuildContext context) {
    final e = envoi;
    final pct = (e.avance * 100).round();
    final envoye = (e.poidsMo * e.avance).toStringAsFixed(1).replaceAll('.', ',');
    final (String detail, String? icone, Color? couleur) = switch (e.etat) {
      EtatEnvoi.encours => (t('{pct} % · {envoye} Mo sur {total} Mo', {'pct': pct, 'envoye': envoye, 'total': e.poidsMo.toStringAsFixed(1).replaceAll('.', ',')}), null, null),
      EtatEnvoi.pause => (e.detail != null ? t('En pause · {pct} % · {raison}', {'pct': pct, 'raison': e.detail}) : t('En pause · {pct} %', {'pct': pct}), null, null),
      EtatEnvoi.verification => (e.detail ?? Envois.enAnalyse, e.attente == 'a_completer' ? 'alerte' : null, null),
      EtatEnvoi.publie => (e.detail ?? t('Publiée'), 'verifie', null),
      EtatEnvoi.refuse => (e.detail ?? t('Refusée'), 'drapeau', Couleurs.erreur),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Plaque(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(width: 48, height: 60, child: PhotoArrondie(e.photo, rayon: 10)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_vu(e.titre), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (icone != null) ...[Icone(icone, taille: 14, couleur: couleur), const SizedBox(width: 4)],
                      Expanded(
                        child: Text(detail, style: TextStyle(fontSize: 12.5, color: couleur ?? Couleurs.discret)),
                      ),
                    ],
                  ),
                  if (e.etat == EtatEnvoi.encours || e.etat == EtatEnvoi.pause) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: e.avance, minHeight: 4, color: e.etat == EtatEnvoi.pause ? Couleurs.discret : Couleurs.ocean, backgroundColor: Couleurs.filet),
                    ),
                  ],
                  // Le logo tourne tant que l analyse tourne ; a completer ou pour l equipe, il s arrete.
                  if (e.etat == EtatEnvoi.verification && e.attente == null) ...[const SizedBox(height: 6), const LogoQuiTourne(taille: 18)],
                ],
              ),
            ),
            if (e.etat == EtatEnvoi.encours || e.etat == EtatEnvoi.pause) ...[
              const SizedBox(width: 8),
              RondVerre(
                icone: e.etat == EtatEnvoi.pause ? 'lecture' : 'pause',
                semantique: e.etat == EtatEnvoi.pause ? t('Reprendre') : t('Mettre en pause'),
                taille: 38,
                onTap: () => Envois.instance.basculer(e),
              ),
              const SizedBox(width: 4),
              RondVerre(icone: 'fermer', semantique: t("Annuler l'envoi"), taille: 38, encre: Couleurs.erreur, onTap: () => Envois.instance.annuler(e)),
            ],
            if (e.etat == EtatEnvoi.verification && e.attente == 'a_completer')
              TextButton(
                onPressed: () => _feuilleCompleter(context, e),
                child: Text(
                  t('Compléter'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: Couleurs.texte, decoration: TextDecoration.underline),
                ),
              ),
            if (e.etat == EtatEnvoi.refuse)
              TextButton(
                // Le vrai motif ; refusee par le serveur, une seconde verification peut se demander.
                onPressed: () => context.push(
                  Uri(
                    path: '/etat/refusee',
                    queryParameters: {'titre': e.titre, if ((e.motif ?? e.detail) != null) 'motif': e.motif ?? e.detail!, if (e.motif != null && e.contenu != null) 'contenu': e.contenu!},
                  ).toString(),
                ),
                child: Text(
                  t('Motif'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: Couleurs.texte, decoration: TextDecoration.underline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un telechargement : sa barre pendant qu il avance, puis « Dans la galerie » ; touche, la
/// photo se rouvre (sous Mes envois).
class _LigneTelechargement extends StatelessWidget {
  const _LigneTelechargement({required this.telecharge});

  final Telecharge telecharge;

  @override
  Widget build(BuildContext context) {
    final d = telecharge;
    final (String detail, String? icone, Color? couleur) = switch (d.etat) {
      EtatTelechargement.encours => (t('{pct} %', {'pct': (d.avance * 100).round()}), null, null),
      EtatTelechargement.ok => (t('Dans la galerie · {quand}', {'quand': ilYA(d.date)}), 'coche', null),
      EtatTelechargement.echec => (t('Téléchargement impossible'), 'alerte', Couleurs.erreur),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Appuyable(
        semantique: d.titre,
        onTap: d.contenu == null ? null : () => context.push(ici(context, 'lieu/_/photo/${d.contenu}')),
        child: Plaque(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(width: 48, height: 60, child: PhotoArrondie(d.photo, rayon: 10)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vu(d.titre),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (icone != null) ...[Icone(icone, taille: 14, couleur: couleur), const SizedBox(width: 4)],
                        Expanded(
                          child: Text(detail, style: TextStyle(fontSize: 12.5, color: couleur ?? Couleurs.discret)),
                        ),
                      ],
                    ),
                    if (d.etat == EtatTelechargement.encours) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(value: d.avance <= 0 ? null : d.avance, minHeight: 4, color: Couleurs.ocean, backgroundColor: Couleurs.filet),
                      ),
                    ],
                  ],
                ),
              ),
              if (d.etat != EtatTelechargement.encours) ...[
                const SizedBox(width: 8),
                RondVerre(icone: 'fermer', semantique: t('Retirer de la liste'), taille: 38, onTap: () => Telechargements.instance.retirer(d)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Une publication « a completer » : ce que le serveur attend (le telephone, la date de
/// la prise) s indique ici, puis la verification reprend (PATCH contenus/{id}).
void _feuilleCompleter(BuildContext context, Envoi e) {
  if (!Communaute.instance.enLigne) {
    bulle(context, t('Connectez-vous pour compléter cette publication.'), icone: 'profil');
    return;
  }
  montrerFeuille<void>(
    context,
    titre: t('Compléter'),
    contenu: (f) => _Completer(envoi: e),
  );
}

class _Completer extends StatefulWidget {
  const _Completer({required this.envoi});

  final Envoi envoi;

  @override
  State<_Completer> createState() => _CompleterState();
}

class _CompleterState extends State<_Completer> {
  late final _telephone = TextEditingController(text: widget.envoi.source?.modele ?? '');
  late DateTime? _date = widget.envoi.source?.priseLe;
  String _ceTelephone = 'Ce téléphone';
  bool _envoi = false;

  // Le serveur ne dit pas ce qui manque (un ancien envoi) : les deux se demandent.
  bool get _sansTelephone => widget.envoi.manque.isEmpty || widget.envoi.manque.contains('telephone');
  bool get _sansDate => widget.envoi.manque.isEmpty || widget.envoi.manque.contains('date');

  @override
  void initState() {
    super.initState();
    modeleDuTelephone().then((m) {
      if (mounted) setState(() => _ceTelephone = m);
    });
  }

  @override
  void dispose() {
    _telephone.dispose();
    super.dispose();
  }

  // La marque et le modele : deux mots au moins.
  bool get _telephoneValide => _telephone.text.trim().contains(' ');

  bool get _pret => (!_sansTelephone || _telephoneValide) && (!_sansDate || _date != null);

  // Le calendrier s arrete a aujourd hui.
  Future<void> _choisirDate() async {
    final aujourdhui = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date != null && !_date!.isAfter(aujourdhui) ? _date! : aujourdhui,
      firstDate: DateTime(1990),
      lastDate: aujourdhui,
      helpText: t('Date de la prise'),
      cancelText: t('Annuler'),
      confirmText: t('OK'),
    );
    if (d != null && mounted) setState(() => _date = DateTime(d.year, d.month, d.day, 12));
  }

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    final erreur = await Envois.instance.completer(widget.envoi, telephone: _sansTelephone ? _telephone.text : null, date: _sansDate ? _date : null);
    if (!mounted) return;
    setState(() => _envoi = false);
    if (erreur != null) {
      bulle(context, erreur, icone: 'alerte');
      return;
    }
    bulle(context, t('Informations envoyées. La vérification reprend.'), icone: 'coche');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('Indiquez ce que le fichier ne dit pas. La publication portera le badge « Informations déclarées ».'), style: Textes.discret),
        if (_sansTelephone) ...[
          const SizedBox(height: 16),
          ChampVerre(
            libelle: t("Le téléphone qui l'a prise"),
            icone: 'telephone',
            indice: t('La marque et le modèle'),
            controleur: _telephone,
            aide: Text(t('Par exemple Google Pixel 8.')),
            onChanged: (_) => setState(() {}),
          ),
          if (_ceTelephone != 'Ce téléphone') ...[
            const SizedBox(height: 6),
            Lien(t('Utiliser ce téléphone : {modele}', {'modele': _ceTelephone}), onTap: () => setState(() => _telephone.text = _ceTelephone)),
          ],
        ],
        if (_sansDate) ...[
          const SizedBox(height: 16),
          Text(t('Date de la prise'), style: Textes.libelle),
          const SizedBox(height: 8),
          Appuyable(
            semantique: t('Choisir la date de la prise'),
            onTap: _choisirDate,
            child: Verre(
              rayon: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icone('calendrier', taille: 21, couleur: Couleurs.texte),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_date == null ? t('Choisir une date') : jourLisible(_date!), style: TextStyle(fontSize: 15.5, color: _date == null ? Couleurs.discret : Couleurs.texte)),
                  ),
                  Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        BoutonVerre(texte: t('Envoyer'), plein: true, enCours: _envoi, onTap: _pret && !_envoi ? _envoyer : null),
      ],
    ),
  );
}

/// La pastille d envoi (E16) : elle flotte au-dessus des onglets tant qu un
/// envoi avance, et mene a « Mes envois ».
class PastilleEnvoi extends StatelessWidget {
  const PastilleEnvoi({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Envois.instance,
    builder: (context, _) {
      final e = Envois.instance.courant;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Courbes.ressort,
        transitionBuilder: (enfant, a) => SlideTransition(
          position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a),
          child: FadeTransition(opacity: a, child: enfant),
        ),
        child: e == null
            ? const SizedBox.shrink()
            : Appuyable(
                key: const ValueKey('envoi'),
                semantique: t('Envoi en cours, {pct} %', {'pct': (e.avance * 100).round()}),
                onTap: () => context.push('/creer/envois'),
                // Le verre d iOS : depoli leger, masse dense, bord en loupe.
                child: VerreLoupe(
                  rayon: 22,
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t('Envoi en cours · {pct} %', {'pct': (e.avance * 100).round()}), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            Text(t('Reprise automatique si le réseau se coupe'), style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(value: e.avance, minHeight: 3.5, color: Couleurs.ocean, backgroundColor: Couleurs.filet),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      RondVerre(icone: 'pause', semantique: t('Mettre en pause'), taille: 38, onTap: () => Envois.instance.basculer(e)),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
