// E24 Moderation et E25 Decision : l equipe trie les publications douteuses
// (signalements, informations declarees, secondes verifications) et les
// commentaires signales, et decide. Le reste est
// publie sans attendre. Pour l administrateur seul : la file du serveur
// (donnees/moderation.dart).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../donnees/communaute.dart';
import '../donnees/modeles.dart' show coordonnees, dateLongue;
import '../donnees/moderation.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/champ.dart';
import '../widgets/feuille.dart';
import '../widgets/feuilles.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';
import 'etats.dart';

class _Dossier {
  _Dossier(this.serveur);

  /// Le dossier du serveur.
  final DossierModeration serveur;

  String get photo => serveur.photo;
  String get titre => serveur.titre;
  String get auteur => serveur.auteur;
  String? get avatarAuteur => serveur.avatarAuteur;
  String get type => serveur.type;

  /// Le type a l ecran : « Photo » ou « Reel ».
  String get nomType => serveur.type == 'reel' ? t('Reel') : t('Photo');

  String get icone => serveur.signale ? 'drapeau' : (RegExp(r'ia', caseSensitive: false).hasMatch(serveur.raison) ? 'etincelle' : 'telephone');

  String get raison => serveur.signale ? '${serveur.signalements > 1 ? t('Signalé {n} fois', {'n': serveur.signalements}) : t('Signalé')} · ${serveur.raison}' : serveur.raison;

  String get quand => ilYA(serveur.depuis);

  /// Plusieurs signalements : la raison passe en rouge.
  bool get forte => serveur.signalements >= 3;
}

class EcranModeration extends StatefulWidget {
  const EcranModeration({super.key, this.file = 0});

  /// La file ouverte : 0 a verifier, 1 les signalements.
  final int file;

  @override
  State<EcranModeration> createState() => _EcranModerationState();
}

// L ordre de la file, range ici sur la date d arrivee (et le nombre de
// signalements pour les signalements), et le type.
enum _Ordre { signales, anciens, recents }

String _nomOrdre(_Ordre o) => switch (o) {
  _Ordre.signales => t('Les plus signalés d’abord'),
  _Ordre.anciens => t('Les plus anciens d’abord'),
  _Ordre.recents => t('Les plus récents d’abord'),
};

List<Motif> get _types => [(t('Photos et reels'), null), (t('Photos'), null), (t('Reels'), null)];

class _EcranModerationState extends State<EcranModeration> {
  late int _file = widget.file;
  int _tri = 0;
  int _type = 0;

  /// La file du serveur (nul : pas encore arrivee).
  List<_Dossier>? _serveur;

  /// Les commentaires en cours de traitement (masquer ou garder).
  final _enAction = <String>{};

  List<_Ordre> get _ordres => _file == 1 ? const [_Ordre.signales, _Ordre.anciens, _Ordre.recents] : const [_Ordre.anciens, _Ordre.recents];

  _Ordre get _ordre => _ordres[_tri.clamp(0, _ordres.length - 1)];

  List<Motif> get _tris => [for (final o in _ordres) (_nomOrdre(o), null)];

  List<_Dossier> _ranges(List<_Dossier> liste) {
    final r = [...liste];
    switch (_ordre) {
      case _Ordre.signales:
        r.sort((a, b) => b.serveur.signalements.compareTo(a.serveur.signalements));
      case _Ordre.anciens:
        r.sort((a, b) => a.serveur.depuis.compareTo(b.serveur.depuis));
      case _Ordre.recents:
        r.sort((a, b) => b.serveur.depuis.compareTo(a.serveur.depuis));
    }
    return r;
  }

  Future<void> _commentaire(CommentaireSignale c, {required bool masquer}) async {
    if (!_enAction.add(c.id)) return;
    setState(() {});
    final ok = masquer ? await Moderation.instance.masquerCommentaire(c.id) : await Moderation.instance.garderCommentaire(c.id);
    if (!mounted) return;
    setState(() => _enAction.remove(c.id));
    if (!ok) {
      bulle(context, masquer ? t('Impossible de masquer le commentaire. Réessayez.') : t('Impossible de classer les signalements. Réessayez.'), icone: 'alerte');
      return;
    }
    bulle(context, masquer ? t('Commentaire masqué.') : t('Commentaire conservé. Ses signalements ont été classés.'), icone: 'coche');
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (!Moderation.instance.ouverte) return;
    final d = await Moderation.instance.file(signalements: _file == 1);
    if (mounted && d != null) setState(() => _serveur = [for (final x in d) _Dossier(x)]);
  }

  Future<void> _filtres() => montrerFeuille<void>(
    context,
    titre: t('Trier la file'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: StatefulBuilder(
        builder: (context, maj) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListeMotifs(
              motifs: _tris,
              choisi: _tri,
              onChoisi: (i) {
                setState(() => _tri = i);
                maj(() {});
              },
            ),
            const SizedBox(height: 14),
            Text(
              t('Afficher'),
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
            ),
            const SizedBox(height: 8),
            ListeMotifs(
              motifs: _types,
              choisi: _type,
              onChoisi: (i) {
                setState(() => _type = i);
                maj(() {});
              },
            ),
            const SizedBox(height: 14),
            BoutonVerre(texte: t('Voir la file'), plein: true, onTap: () => Navigator.pop(f)),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final serveur = _serveur;
    final files = [(t('À vérifier'), Moderation.instance.totaux['a_verifier'] ?? 0), (t('Signalements'), Moderation.instance.signalesEnTout)];
    var dossiers = serveur ?? const <_Dossier>[];
    if (_type > 0) dossiers = dossiers.where((d) => d.type == (_type == 1 ? 'photo' : 'reel')).toList();
    dossiers = _ranges(dossiers);
    final tous = dossiers;
    // Les commentaires signales, sous les publications (ni photos ni reels : seulement avec « Photos et reels »).
    final commentaires = _file == 1 && serveur != null && _type == 0 ? Moderation.instance.commentaires : const <CommentaireSignale>[];
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              const Spacer(),
              RondVerre(icone: 'filtres', semantique: t('Filtres'), onTap: _filtres),
            ],
          ),
          const SizedBox(height: 14),
          Titre(t('Modération'), style: Textes.titre),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final (i, (nom, n)) in files.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Pastille(
                    texte: '$nom  $n',
                    retenue: _file == i,
                    onTap: () {
                      setState(() {
                        _file = i;
                        _tri = 0;
                      });
                      _charger();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_file == 0 ? t('{ordre}. Les autres publications sont mises en ligne directement.', {'ordre': _nomOrdre(_ordre)}) : '${_nomOrdre(_ordre)}.', style: Textes.petit),
          const SizedBox(height: 8),
          if (serveur != null && dossiers.isEmpty && commentaires.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(t('Aucun dossier à traiter pour l’instant.'), style: Textes.discret, textAlign: TextAlign.center),
            ),
          for (final d in dossiers)
            InkWell(
              borderRadius: BorderRadius.circular(Mesures.rayonPlaque),
              onTap: () async {
                _enCours = tous;
                await context.push('/moderation/decision?n=${tous.indexOf(d)}');
                _charger();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    SizedBox(width: 64, height: 64, child: PhotoArrondie(d.photo, rayon: 12)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.titre, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                          Text('@${d.auteur} · ${d.nomType}', style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icone(d.icone, taille: 14, couleur: d.forte ? Couleurs.erreur : Couleurs.texte),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  d.raison,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: d.forte ? Couleurs.erreur : Couleurs.texte),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(d.quand, style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                  ],
                ),
              ),
            ),
          if (commentaires.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(t('Commentaires signalés'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final c in commentaires)
              _LigneCommentaire(commentaire: c, occupe: _enAction.contains(c.id), onGarder: () => _commentaire(c, masquer: false), onMasquer: () => _commentaire(c, masquer: true)),
          ],
        ],
      ),
    );
  }
}

/// Un commentaire signale : son auteur, son texte, et les deux decisions.
class _LigneCommentaire extends StatelessWidget {
  const _LigneCommentaire({required this.commentaire, required this.occupe, required this.onGarder, required this.onMasquer});

  final CommentaireSignale commentaire;
  final bool occupe;
  final VoidCallback onGarder;
  final VoidCallback onMasquer;

  @override
  Widget build(BuildContext context) {
    final c = commentaire;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(nom: c.nomAuteur ?? c.auteur, taille: 36, photo: c.avatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${c.auteur}${c.creeLe == null ? '' : ' · ${ilYA(c.creeLe!)}'}', style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                    const SizedBox(height: 2),
                    Text(c.texte, style: const TextStyle(fontSize: 14.5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 46),
              Expanded(
                child: BoutonVerre(texte: t('Masquer'), icone: 'oeil-barre', teinte: TeinteVerre.rouge, onTap: occupe ? null : onMasquer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BoutonVerre(texte: t('Conserver'), icone: 'coche', teinte: TeinteVerre.limonade, onTap: occupe ? null : onGarder),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// La file que l on parcourt dans l ecran de decision.
List<_Dossier> _enCours = const [];

/// Les motifs de refus, tels qu ils partent au serveur.
const _motifsRefus = ['Image générée ou retouchée par IA', 'Informations fausses', 'Autre motif'];

/// Les memes, a l ecran, dans la langue choisie.
List<Motif> get _motifsAffiches => [(t('Image générée ou retouchée par IA'), null), (t('Informations fausses'), null), (t('Autre motif'), t('Décrivez le motif. L’auteur pourra le lire.'))];

/// Le rang de « Autre motif » : son texte part a la place du libelle.
const _autre = 2;

/// Au-dela, la position de la prise est trop loin du lieu choisi.
const _ecartMaxKm = 10.0;

class EcranDecision extends StatefulWidget {
  const EcranDecision({super.key, this.index = 0});

  final int index;

  @override
  State<EcranDecision> createState() => _EcranDecisionState();
}

class _EcranDecisionState extends State<EcranDecision> {
  int? _motif = 0;
  final _autreMotif = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _autreMotif.dispose();
    super.dispose();
  }

  String? get _motifChoisi {
    final m = _motif;
    if (m == null) return null;
    if (m != _autre) return _motifsRefus[m];
    final texte = _autreMotif.text.trim();
    return texte.length < 3 || texte.length > 300 ? null : texte;
  }

  Future<void> _decider(bool publier) async {
    final s = _enCours[widget.index.clamp(0, _enCours.length - 1)].serveur;
    setState(() => _envoi = true);
    // Deja en ligne et signalee : « Conserver » classe les signalements, « Retirer » la refuse.
    final String? message;
    if (publier && s.signale) {
      message = await Moderation.instance.classer(s.contenu) ? t('Publication conservée. Les signalements ont été classés.') : null;
    } else {
      message = await Moderation.instance.decider(s.contenu, publier: publier, motif: publier ? null : _motifChoisi);
    }
    if (!mounted) return;
    setState(() => _envoi = false);
    if (message == null) {
      bulle(context, t('Impossible d’envoyer la décision. Réessayez.'), icone: 'alerte');
      return;
    }
    bulle(context, message, icone: publier ? 'coche' : 'drapeau');
    final suivant = widget.index + 1;
    if (suivant < _enCours.length) {
      context.pushReplacement('/moderation/decision?n=$suivant');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enCours.isEmpty) return const EcranEtat(etat: 'introuvable');
    final d = _enCours[widget.index.clamp(0, _enCours.length - 1)];
    final s = d.serveur;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final autre = _motif == _autre;
    final longueur = _autreMotif.text.trim().length;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              Expanded(
                child: Text(
                  t('Dossier {n} sur {total}', {'n': widget.index + 1, 'total': _enCours.length}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(aspectRatio: 4 / 3, child: PhotoArrondie(d.photo, rayon: 20)),
          const SizedBox(height: 14),
          Row(
            children: [
              Avatar(nom: d.auteur, taille: 40, photo: d.avatarAuteur),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.titre, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text('@${d.auteur} · ${d.nomType}', style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Plaque(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icone(d.icone, taille: 20, couleur: Couleurs.texte),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(d.raison, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.signale
                      ? t('Cette publication est en ligne. Conservez-la si les signalements ne sont pas fondés. Sinon, retirez-la.')
                      : s.recours
                      ? t('Cette publication a été refusée, et son auteur demande une seconde vérification. Comparez le fichier et les informations déclarées.')
                      : t('L’analyse automatique n’a pas pu se prononcer. Comparez le fichier et les informations déclarées.'),
                  style: Textes.petit.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Plaque(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Fichier et informations déclarées'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _Compare(
                  icone: 'telephone',
                  quoi: t('Téléphone'),
                  valeur: s.telephone ?? t('Non indiqué'),
                  detail: _source(s.origineTelephone),
                  etat: _etatSource(s.origineTelephone, s.telephone != null),
                ),
                _Compare(
                  icone: 'calendrier',
                  quoi: t('Prise le'),
                  valeur: s.priseLe == null ? t('Non indiquée') : dateLongue(s.priseLe!),
                  detail: _source(s.origineDate),
                  etat: _etatSource(s.origineDate, s.priseLe != null),
                ),
                _lieu(s),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(t('Motif du refus'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ListeMotifs(motifs: _motifsAffiches, choisi: _motif, onChoisi: (i) => setState(() => _motif = i)),
          if (autre) ...[
            const SizedBox(height: 10),
            ChampVerre(
              icone: 'commentaire',
              indice: t('Décrivez le motif en une phrase'),
              controleur: _autreMotif,
              lignes: 2,
              autofocus: true,
              erreur: longueur > 300 ? t('300 caractères maximum ({n}).', {'n': longueur}) : null,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            s.recours ? t('L’auteur recevra le motif. Il a déjà demandé une seconde vérification.') : t('L’auteur recevra le motif et pourra demander une seconde vérification, une seule fois.'),
            style: Textes.petit,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BoutonVerre(texte: s.signale ? t('Retirer') : t('Refuser'), icone: 'fermer', teinte: TeinteVerre.rouge, onTap: _envoi || _motifChoisi == null ? null : () => _decider(false)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BoutonVerre(texte: s.signale ? t('Conserver') : t('Publier'), icone: 'coche', teinte: TeinteVerre.limonade, onTap: _envoi ? null : () => _decider(true)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Le lieu : celui choisi par l auteur, et l ecart avec la position de la prise.
  Widget _lieu(DossierModeration s) {
    final declare = s.lieu ?? t('Aucun lieu');
    if (s.latitude == null || s.longitude == null) {
      return _Compare(icone: 'lieu', quoi: t('Lieu'), valeur: declare, detail: t('Aucune position pour la prise de vue'), etat: (t('Sans position'), 0));
    }
    final position = '${coordonnees(s.latitude!, s.longitude!)} · ${_source(s.originePosition)}';
    if (s.lieuLatitude == null || s.lieuLongitude == null) {
      return _Compare(icone: 'lieu', quoi: t('Lieu'), valeur: declare, detail: position, etat: _etatSource(s.originePosition, true));
    }
    final km = _distanceKm(s.latitude!, s.longitude!, s.lieuLatitude!, s.lieuLongitude!);
    final ecart = km < 1 ? t('À moins d’1 km du lieu') : t('À {n} km du lieu', {'n': km.round()});
    final lue = s.originePosition == 'exif' || s.originePosition == 'appareil';
    return _Compare(icone: 'lieu', quoi: t('Lieu'), valeur: declare, detail: '$ecart · $position', etat: km > _ecartMaxKm ? (t('Diffère'), -1) : (lue ? (t('Concorde'), 1) : (t('Déclaré'), 0)));
  }
}

/// D ou vient une information de la prise, en clair.
String _source(String? origine) => switch (origine) {
  'exif' => t('Lu dans le fichier'),
  'appareil' => t('Lu par l’appareil photo de Discover'),
  'declaree' => t('Déclaré par l’auteur'),
  _ => t('Origine non indiquée'),
};

/// Le badge d une ligne : vert si le fichier ou l appareil l a lu, neutre sinon.
(String, int) _etatSource(String? origine, bool connue) {
  if (!connue) return (t('Absent'), 0);
  return origine == 'exif' || origine == 'appareil' ? (t('Lu'), 1) : (t('Déclaré'), 0);
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * 6371.0088 * math.asin(math.min(1.0, math.sqrt(a.toDouble())));
}

/// Une ligne de la fiche : la valeur, d ou elle vient, et un badge
/// (`etat` : son texte et son ton, 1 vert, 0 neutre, -1 rouge).
class _Compare extends StatelessWidget {
  const _Compare({required this.icone, required this.quoi, required this.valeur, required this.detail, required this.etat});

  final String icone;
  final String quoi;
  final String valeur;
  final String detail;
  final (String, int) etat;

  @override
  Widget build(BuildContext context) {
    final (texte, ton) = etat;
    final encre = switch (ton) {
      1 => Couleurs.encreLimonade,
      -1 => Couleurs.erreur,
      _ => Couleurs.discret,
    };
    final fond = switch (ton) {
      1 => Couleurs.limonade.withValues(alpha: 0.35),
      -1 => Couleurs.erreur.withValues(alpha: 0.12),
      _ => Couleurs.filet,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icone(icone, taille: 20, couleur: Couleurs.texte),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quoi, style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                Text(valeur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(detail, style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ton != 0) ...[Icone(ton > 0 ? 'coche' : 'alerte', taille: 13, couleur: encre), const SizedBox(width: 4)],
                Text(
                  texte,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: encre),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
