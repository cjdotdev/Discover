// Les feuilles d une photo ou d un reel (E07 commentaires, E08 telecharger,
// E09 enregistrer, E10 partager, E06 reactions, E22 signaler), communes a la page Photo et
// aux reels. Toutes en verre liquide (feuille.dart).
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../outils/api.dart';
import '../donnees/communaute.dart';
import '../donnees/modeles.dart';
import '../donnees/session.dart';
import '../donnees/telechargements.dart';
import '../donnees/vues.dart';
import '../outils/capacites.dart';
import '../outils/chemins.dart';
import '../outils/langue.dart';
import '../donnees/lieux_enregistres.dart' show nombrePublications;
import '../outils/partage.dart';
import '../outils/verrou.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import 'avatar.dart';
import 'champ.dart';
import 'feuille.dart';
import 'icone.dart';
import 'page.dart';
import 'photo.dart';
import 'verre.dart';

TextStyle get _sousTitre => TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte);

// ------------------------------------------------------------ E07 commentaires

/// `contenu` : la publication sur le serveur (ses commentaires) ; nul : pas encore en ligne, on ne peut pas commenter.
/// `monContenu` : c est ma publication (je peux epingler, ou retirer un commentaire).
/// `nombre` : le nombre du serveur ; celui que mes gestes ont change s affiche (Communaute).
Future<void> feuilleCommentaires(BuildContext context, {required int nombre, required String auteur, String? contenu, bool monContenu = false}) {
  if (contenu != null) Communaute.instance.connaitreCommentaires(contenu, nombre);
  // Le titre suit chaque ajout ou suppression, sans fermer la feuille.
  String titre() {
    final n = Communaute.instance.nombreCommentaires(contenu, nombre);
    return tn(n, '{n} commentaire', '{n} commentaires');
  }

  return montrerFeuille<void>(
    context,
    titre: titre(),
    titreVivant: titre,
    suit: Communaute.instance,
    contenu: (_) => _Commentaires(auteur: auteur, contenu: contenu, monContenu: monContenu),
  );
}

class _Avis {
  _Avis(
    this.nom,
    this.texte,
    this.quand,
    this.aime, {
    this.auteur = false,
    this.epingle = false,
    this.reponseA,
    this.id,
    this.avatar,
    this.mien = false,
    this.reponsesServeur = 0,
    this.modifie = false,
    this.pseudo = '',
    this.cree,
  });

  /// Depuis le serveur : `aime` ne compte pas mon « j aime », ajoute a l affichage.
  factory _Avis.serveur(CommentaireServeur c) => _Avis(
    c.mien ? t('Vous') : c.nom,
    c.texte,
    ilYA(c.quand),
    c.jaime - (c.aimeParMoi ? 1 : 0),
    auteur: c.deLAuteur,
    epingle: c.epingle,
    reponseA: c.repondA,
    id: c.id,
    avatar: c.avatar,
    mien: c.mien,
    reponsesServeur: c.reponses,
    modifie: c.modifie,
    pseudo: c.pseudo,
    cree: c.quand,
  )..aimeParMoi = c.aimeParMoi;

  /// Quand il a ete ecrit (nul : il vient de l etre, pas encore confirme par le serveur).
  final DateTime? cree;

  /// Comme une publication : il se modifie pendant 1 h, ensuite il ne peut que se supprimer.
  bool get modifiable => cree == null || DateTime.now().difference(cree!) < const Duration(hours: 1);

  final String nom;

  /// Son nom d utilisateur : celui qu une @mention atteint.
  final String pseudo;
  String texte;
  final String quand;
  final int aime;
  bool modifie;
  final bool auteur;
  bool epingle;

  /// Une reponse : le nom de celui a qui elle repond. Elle se range sous son commentaire.
  final String? reponseA;

  /// Sur le serveur : son identifiant, la photo de son auteur, s il est de moi.
  final String? id;
  final String? avatar;
  final bool mien;

  /// Ses reponses sur le serveur, avant qu on les deplie (elles arrivent alors).
  final int reponsesServeur;

  bool aimeParMoi = false;
}

class _Commentaires extends StatefulWidget {
  const _Commentaires({required this.auteur, this.contenu, this.monContenu = false});

  final String auteur;
  final String? contenu;
  final bool monContenu;

  @override
  State<_Commentaires> createState() => _CommentairesState();
}

class _CommentairesState extends State<_Commentaires> {
  final _saisie = TextEditingController();
  final _focus = FocusNode();

  /// La publication est en ligne : ses commentaires viennent du serveur.
  bool get _serveur => widget.contenu != null;
  bool _charge = false;

  /// Le chargement a echoue : on le dit, avec de quoi reessayer.
  bool _erreur = false;

  @override
  void initState() {
    super.initState();
    if (_serveur) _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = false;
      _erreur = false;
    });
    final liste = await Communaute.instance.commentaires(widget.contenu!);
    if (!mounted) return;
    setState(() {
      _charge = true;
      _erreur = liste == null;
      _fils.clear();
      _deplies.clear();
      for (final c in liste ?? const <CommentaireServeur>[]) {
        _fils.add([_Avis.serveur(c)]);
      }
    });
  }

  // Deplier un fil du serveur : ses reponses arrivent.
  Future<void> _deplier(int i) async {
    setState(() => _deplies.add(i));
    final premier = _fils[i].first;
    if (premier.id == null || _fils[i].length > 1) return;
    final reponses = await Communaute.instance.reponses(premier.id!);
    if (!mounted || reponses == null) return;
    setState(() => _fils[i].addAll([for (final r in reponses) _Avis.serveur(r)]));
  }

  // Un appui long : modifier (le mien), retirer (le mien, ou n importe lequel chez moi), epingler (chez moi).
  void _options(int fil, _Avis a) {
    if (!_serveur || a.id == null || !(a.mien || widget.monContenu)) return;
    HapticFeedback.selectionClick();
    montrerFeuille<void>(
      context,
      titre: t('Ce commentaire'),
      contenu: (f) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.monContenu && a.reponseA == null)
              LigneFeuille(
                icone: 'epingle',
                texte: a.epingle ? t('Détacher') : t('Épingler en haut'),
                onTap: () async {
                  Navigator.pop(f);
                  final epingle = await Communaute.instance.epingler(a.id!);
                  if (!mounted || epingle == null) return;
                  setState(() {
                    for (final x in _fils) {
                      x.first.epingle = false;
                    }
                    a.epingle = epingle;
                    if (epingle) _fils.insert(0, _fils.removeAt(fil));
                  });
                },
              ),
            if (a.mien && a.modifiable)
              LigneFeuille(
                icone: 'crayon',
                texte: t('Modifier'),
                onTap: () {
                  Navigator.pop(f);
                  setState(() {
                    _repondre = null;
                    _modifie = a;
                  });
                  _saisie.value = TextEditingValue(
                    text: a.texte,
                    selection: TextSelection.collapsed(offset: a.texte.length),
                  );
                  _focus.requestFocus();
                },
              ),
            LigneFeuille(
              icone: 'poubelle',
              texte: t('Supprimer'),
              danger: true,
              onTap: () async {
                Navigator.pop(f);
                // Il part tout de suite, partout (la feuille, la page de la photo, les nombres) ;
                // il revient a sa place si le serveur refuse.
                final premier = identical(_fils[fil].first, a);
                final fils = _fils[fil];
                final rang = fils.indexOf(a);
                final reponses = premier ? math.max(fils.length - 1, a.reponsesServeur) : 0;
                setState(() => premier ? _fils.removeAt(fil) : fils.remove(a));
                Communaute.instance.commentaireRetire(widget.contenu!, a.id!, reponses: reponses);
                final ok = await Communaute.instance.supprimerCommentaire(a.id!);
                if (ok) return;
                Communaute.instance.commentaireRendu(widget.contenu!, a.id!, reponses: reponses);
                if (!mounted) return;
                setState(() => premier ? _fils.insert(fil.clamp(0, _fils.length), fils) : fils.insert(rang.clamp(0, fils.length), a));
                bulle(context, t('Impossible de supprimer le commentaire. Réessayez.'), icone: 'alerte');
              },
            ),
          ],
        ),
      ),
    );
  }

  // Les commentaires du serveur, chacun suivi de ses reponses.
  final _fils = <List<_Avis>>[];

  // A qui l on repond : le fil et le nom.
  (int, String)? _repondre;

  // Le commentaire que je retouche : la saisie le remplace.
  _Avis? _modifie;

  // Les fils dont les reponses sont depliees.
  final _deplies = <int>{};

  @override
  void dispose() {
    _saisie.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Ceux qu on peut mentionner : les gens du fil et les createurs suivis.
  List<String> get _gens => {
    for (final f in _fils)
      for (final a in f)
        if (!a.mien && a.pseudo.isNotEmpty) a.pseudo,
    ...Communaute.instance.suivis,
  }.toList();

  // Leur photo de profil, connue par leurs commentaires (les createurs suivis : leurs initiales).
  Map<String, String?> get _photosDesGens => {
    for (final f in _fils)
      for (final a in f)
        if (a.pseudo.isNotEmpty && a.avatar != null) a.pseudo: a.avatar,
  };

  // Le mot tape juste avant le curseur, s il commence par @.
  String? get _mentionEnCours {
    final t = _saisie.text;
    final fin = _saisie.selection.baseOffset < 0 ? t.length : _saisie.selection.baseOffset;
    final m = RegExp(r'@([\w.]*)$').firstMatch(t.substring(0, fin.clamp(0, t.length)));
    return m?.group(1);
  }

  List<String> get _suggestions {
    final debut = _mentionEnCours;
    if (debut == null) return const [];
    return _gens.where((g) => g.startsWith(debut.toLowerCase()) && g != debut).take(5).toList();
  }

  void _mentionner(String pseudo) {
    final t = _saisie.text;
    final fin = _saisie.selection.baseOffset < 0 ? t.length : _saisie.selection.baseOffset.clamp(0, t.length);
    final avant = t.substring(0, fin).replaceFirst(RegExp(r'@[\w.]*$'), '@$pseudo ');
    final texte = avant + t.substring(fin);
    _saisie.value = TextEditingValue(
      text: texte,
      selection: TextSelection.collapsed(offset: avant.length),
    );
    setState(() {});
  }

  void _repondreA(int fil, _Avis a) {
    HapticFeedback.selectionClick();
    setState(() {
      _modifie = null;
      _repondre = (fil, a.nom);
    });
    _focus.requestFocus();
  }

  void _envoyer() {
    final texte = _saisie.text.trim();
    if (texte.isEmpty || !_serveur) return;
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour commenter.'), icone: 'profil');
      return;
    }
    HapticFeedback.lightImpact();
    final retouche = _modifie;
    if (retouche != null) {
      _retoucher(retouche, texte);
      return;
    }
    final r = _repondre;
    // Il s affiche tout de suite ; le serveur le confirme ensuite.
    final provisoire = _Avis(t('Vous'), texte, t('maintenant'), 0, reponseA: r?.$2, mien: true);
    final aRepondre = r == null ? null : _fils[r.$1].firstWhere((a) => a.nom == r.$2, orElse: () => _fils[r.$1].first);
    setState(() {
      if (r == null) {
        // Un nouveau commentaire : juste sous l epingle.
        final apres = _fils.isNotEmpty && _fils.first.first.epingle ? 1 : 0;
        _fils.insert(apres.clamp(0, _fils.length), [provisoire]);
      } else {
        _fils[r.$1].add(provisoire);
        _deplies.add(r.$1);
      }
      _repondre = null;
      _saisie.clear();
    });
    // La page de la photo le montre aussi tout de suite (un commentaire, pas une reponse).
    final surLaPage = r != null
        ? null
        : CommentaireServeur(
            id: 'provisoire-${DateTime.now().microsecondsSinceEpoch}',
            texte: texte,
            pseudo: Session.instance.nomUtilisateur,
            nom: Session.instance.nomAffiche.isEmpty ? Session.instance.nomUtilisateur : Session.instance.nomAffiche,
            avatar: Session.instance.photo ?? Session.instance.avatar,
            quand: DateTime.now(),
            jaime: 0,
            reponses: 0,
            epingle: false,
            deLAuteur: widget.monContenu,
            aimeParMoi: false,
            mien: true,
          );
    Communaute.instance.commentaireAjoute(widget.contenu!, provisoire: surLaPage);
    Communaute.instance
        .commenter(widget.contenu!, texte, parent: aRepondre?.id)
        .then(
          (c) {
            if (surLaPage != null) Communaute.instance.commentaireConfirme(widget.contenu!, surLaPage, c);
            if (!mounted) return;
            setState(() {
              for (final fil in _fils) {
                final i = fil.indexOf(provisoire);
                if (i >= 0) fil[i] = _Avis.serveur(c);
              }
            });
          },
          onError: (Object e) {
            Communaute.instance.commentaireAnnule(widget.contenu!, provisoire: surLaPage);
            if (!mounted) return;
            setState(() {
              _fils.removeWhere((fil) => identical(fil.first, provisoire));
              for (final fil in _fils) {
                fil.remove(provisoire);
              }
            });
            bulle(context, e is ErreurApi ? e.message : t('Impossible d’envoyer le commentaire. Vérifiez votre connexion, puis réessayez.'), icone: 'alerte');
          },
        );
  }

  // Le nouveau texte s affiche tout de suite ; l ancien revient si le serveur refuse.
  Future<void> _retoucher(_Avis a, String texte) async {
    final avant = (a.texte, a.modifie);
    setState(() {
      a.texte = texte;
      a.modifie = true;
      _modifie = null;
      _saisie.clear();
    });
    if (texte == avant.$1) return;
    final c = await Communaute.instance.modifierCommentaire(a.id!, texte);
    if (!mounted) return;
    if (c == null) {
      setState(() {
        a.texte = avant.$1;
        a.modifie = avant.$2;
      });
      bulle(context, t('Impossible de modifier le commentaire. Réessayez.'), icone: 'alerte');
    }
  }

  // Le coeur d un commentaire : tout de suite a l ecran, puis au serveur ; il revient s il refuse.
  Future<void> _aimer(_Avis a) async {
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour aimer un commentaire.'), icone: 'profil');
      return;
    }
    // Mon commentaire tout juste ecrit : il n est pas encore sur le serveur.
    if (a.id == null) return;
    HapticFeedback.selectionClick();
    final oui = !a.aimeParMoi;
    setState(() => a.aimeParMoi = oui);
    if (!await Communaute.instance.aimerCommentaire(a.id!, oui) && mounted) {
      setState(() => a.aimeParMoi = !oui);
      bulle(context, t('Aucune connexion. Réessayez dans un instant.'), icone: 'hors-ligne');
    }
  }

  Widget _avis(int fil, _Avis a) {
    final reponse = a.reponseA != null;
    return GestureDetector(
      onLongPress: () => _options(fil, a),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(bottom: 14, left: reponse ? 44 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mon commentaire : ma photo de profil (pas le « V » de « Vous »).
            if (a.mien) AvatarMoi(taille: reponse ? 26 : 34) else Avatar(nom: a.nom, taille: reponse ? 26 : 34, photo: a.avatar),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.epingle)
                    Text(
                      t('Épinglé par l’auteur'),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Couleurs.discret),
                    ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.nom,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (a.auteur) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Couleurs.texte.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text(t('Auteur'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  if (reponse)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(t('Réponse à {nom}', {'nom': a.reponseA}), style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                    ),
                  const SizedBox(height: 2),
                  TexteMentions(a.texte),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(a.modifie ? t('{quand} · modifié', {'quand': a.quand}) : a.quand, style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => _repondreA(fil, a),
                        child: Text(
                          t('Répondre'),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Couleurs.discret),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _aimer(a),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Column(
                  children: [
                    Icone(a.aimeParMoi ? 'coeur-plein' : 'coeur', taille: 18, couleur: a.aimeParMoi ? Couleurs.erreur : Couleurs.discret),
                    Text('${a.aime + (a.aimeParMoi ? 1 : 0)}', style: TextStyle(fontSize: 11.5, color: Couleurs.discret)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final photos = suggestions.isEmpty ? const <String, String?>{} : _photosDesGens;
    final r = _repondre;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_serveur)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Text(t('Vous pourrez commenter une fois la publication en ligne.'), style: Textes.discret, textAlign: TextAlign.center),
          )
        else if (_erreur)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              children: [
                Text(t('Impossible de charger les commentaires.'), style: Textes.discret, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                BoutonVerre(texte: t('Réessayer'), large: false, onTap: _charger),
              ],
            ),
          )
        else if (_fils.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Text(_charge ? t('Aucun commentaire pour le moment.') : t('Chargement des commentaires…'), style: Textes.discret, textAlign: TextAlign.center),
          ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
            itemCount: _fils.length,
            itemBuilder: (context, i) {
              final fil = _fils[i];
              final reponses = math.max(fil.length - 1, fil.first.reponsesServeur);
              final deplie = _deplies.contains(i);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avis(i, fil.first),
                  if (deplie)
                    for (final a in fil.skip(1)) _avis(i, a),
                  if (reponses > 0)
                    GestureDetector(
                      onTap: () => deplie ? setState(() => _deplies.remove(i)) : _deplier(i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 44, bottom: 14),
                        child: Row(
                          children: [
                            Container(width: 22, height: 1, color: Couleurs.trait),
                            const SizedBox(width: 8),
                            Text(
                              deplie ? t('Masquer les réponses') : tn(reponses, 'Voir {n} réponse', 'Voir {n} réponses'),
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Couleurs.discret),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // Les @mentions proposees pendant qu on tape.
        if (suggestions.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final g in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _mentionner(g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: Couleurs.sombre ? 0.1 : 0.55),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Avatar(nom: g, taille: 22, photo: photos[g]),
                            const SizedBox(width: 6),
                            Text('@$g', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Le commentaire que je retouche, avec de quoi annuler.
        if (_modifie != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(t('Modifier mon commentaire'), style: TextStyle(fontSize: 13, color: Couleurs.discret)),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _modifie = null);
                    _saisie.clear();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icone('fermer', taille: 16, couleur: Couleurs.discret),
                  ),
                ),
              ],
            ),
          ),
        // A qui l on repond, avec de quoi l annuler.
        if (r != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(t('Réponse à {nom}', {'nom': r.$2}), style: TextStyle(fontSize: 13, color: Couleurs.discret)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _repondre = null),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icone('fermer', taille: 16, couleur: Couleurs.discret),
                  ),
                ),
              ],
            ),
          ),
        if (_serveur)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: ChampVerre(
              icone: 'commentaire',
              indice: r == null ? t('Ajouter un commentaire, @mentionner…') : t('Votre réponse…'),
              controleur: _saisie,
              focus: _focus,
              action: TextInputAction.send,
              onSubmitted: (_) => _envoyer(),
              onChanged: (_) => setState(() {}),
              suffixe: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: BoutonEnvoyer(actif: _saisie.text.trim().isNotEmpty, onTap: _envoyer),
              ),
            ),
          ),
      ],
    );
  }
}

/// Un texte ou les @mentions et les moments (0:12) ressortent.
class TexteMentions extends StatelessWidget {
  const TexteMentions(this.texte, {super.key, this.couleur});

  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final morceaux = <TextSpan>[];
    texte.splitMapJoin(
      RegExp(r'@[\w.]+|\b\d:\d\d\b'),
      onMatch: (m) {
        morceaux.add(
          TextSpan(
            text: m[0],
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        return '';
      },
      onNonMatch: (t) {
        morceaux.add(TextSpan(text: t));
        return '';
      },
    );
    return Text.rich(
      TextSpan(children: morceaux),
      style: TextStyle(fontSize: 14.5, height: 1.4, color: couleur ?? Couleurs.texte),
    );
  }
}

// ------------------------------------------------------------ E10 partager

Future<void> feuillePartager(
  BuildContext context, {
  required String titre,
  required String sousTitre,
  required String photo,
  required String lien,
  VoidCallback? telecharger,
  VoidCallback? enregistrer,
  VoidCallback? signaler,
  String? contenu,
  VoidCallback? pasInteresse,
  bool profil = false,
  String? auteur,
  String? avatarAuteur,
}) => montrerFeuille<void>(
  context,
  titre: t('Partager'),
  contenu: (f) => _Partager(
    titre: titre,
    sousTitre: sousTitre,
    photo: photo,
    lien: lien,
    telecharger: telecharger,
    enregistrer: enregistrer,
    signaler: signaler,
    contenu: contenu,
    pasInteresse: pasInteresse,
    profil: profil,
    auteur: auteur,
    avatarAuteur: avatarAuteur,
  ),
);

class _Partager extends StatefulWidget {
  const _Partager({
    required this.titre,
    required this.sousTitre,
    required this.photo,
    required this.lien,
    this.telecharger,
    this.enregistrer,
    this.signaler,
    this.contenu,
    this.pasInteresse,
    this.profil = false,
    this.auteur,
    this.avatarAuteur,
  });

  /// Le nom de l auteur d une publication partagee, et sa photo de profil : devant le sous-titre.
  final String? auteur;
  final String? avatarAuteur;

  /// La publication sur le serveur : chaque partage y est compte.
  final String? contenu;

  /// « Pas intéressé » : la publication d un autre sort de mes fils (nul sinon).
  final VoidCallback? pasInteresse;

  /// Un profil partage : sa photo ronde, pas une photo de publication.
  final bool profil;

  final String titre;
  final String sousTitre;
  final String photo;
  final String lien;
  final VoidCallback? telecharger;
  final VoidCallback? enregistrer;
  final VoidCallback? signaler;

  @override
  State<_Partager> createState() => _PartagerState();
}

class _PartagerState extends State<_Partager> {
  void _fermer(String message) {
    Navigator.pop(context);
    bulle(context, message);
  }

  String get _texte => texteDePartage(widget.titre, widget.lien);

  // Une autre application : la feuille se ferme, et un message seulement si
  // elle n a pas pu s ouvrir.
  Future<void> _ailleurs(Future<bool> ouverture, String echec) async {
    Communaute.instance.partager(widget.contenu);
    final messager = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    if (!await ouverture && messager != null && messager.mounted) bulle(messager.context, echec, icone: 'alerte');
  }

  Widget _appli(String icone, String nom, VoidCallback onTap, {bool rouge = false, double? largeur = 72}) => SizedBox(
    width: largeur,
    child: Appuyable(
      semantique: nom,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: rouge ? Couleurs.erreur.withValues(alpha: 0.1) : Couleurs.surface.withValues(alpha: 0.8), shape: BoxShape.circle),
            child: Icone(icone, taille: 24, couleur: rouge ? Couleurs.erreur : (icone == 'whatsapp' ? null : Couleurs.texte)),
          ),
          const SizedBox(height: 6),
          Text(
            nom,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: 12, height: 1.2, color: rouge ? Couleurs.erreur : Couleurs.texte),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            children: [
              Row(
                children: [
                  // Un profil : sa photo ronde (ou ses initiales) ; le reste : la photo partagee.
                  if (widget.profil)
                    Avatar(nom: widget.titre, taille: 56, photo: aUnePhoto(widget.photo) ? widget.photo : null)
                  else
                    SizedBox(width: 52, height: 68, child: PhotoArrondie(widget.photo, rayon: 10)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.titre, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                        if (widget.auteur != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Avatar(nom: widget.auteur!, taille: 22, photo: widget.avatarAuteur),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.sousTitre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: Couleurs.discret),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(widget.sousTitre, style: TextStyle(fontSize: 13, color: Couleurs.discret)),
                        Text(
                          widget.lien,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Couleurs.texte),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ...[
                const SizedBox(height: 18),
                Text(t('Partager avec'), style: _sousTitre),
                const SizedBox(height: 10),
                // Les cinq se partagent la largeur : defilant, le dernier (« Autres ») etait coupe au bord.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in [
                      _appli('whatsapp', 'WhatsApp', () => _ailleurs(partagerWhatsApp(_texte), t('Impossible d’ouvrir WhatsApp.')), largeur: null),
                      _appli('lien', t('Copier le lien'), () {
                        Clipboard.setData(ClipboardData(text: 'https://${widget.lien}'));
                        Communaute.instance.partager(widget.contenu);
                        _fermer(t('Lien copié.'));
                      }, largeur: null),
                      _appli('envoyer', t('SMS'), () => _ailleurs(partagerSms(_texte), t('Impossible d’ouvrir l’application de messages.')), largeur: null),
                      _appli('enveloppe', t('E-mail'), () => _ailleurs(partagerEmail(widget.titre, _texte), t('Aucune application de messagerie n’est installée.')), largeur: null),
                      _appli(
                        'plus-points',
                        t('Autres'),
                        () => _ailleurs(partagerAilleurs(_texte, photo: widget.photo, objet: widget.titre), t('Impossible d’ouvrir le partage. Réessayez.')),
                        largeur: null,
                      ),
                    ])
                      Expanded(child: a),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: Couleurs.filet),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.telecharger != null)
                        _appli('telecharger', t('Télécharger'), () {
                          Navigator.pop(context);
                          widget.telecharger!();
                        }),
                      if (widget.enregistrer != null)
                        _appli('enregistrer', t('Enregistrer'), () {
                          Navigator.pop(context);
                          widget.enregistrer!();
                        }),
                      // Seulement pour la publication d un autre : elle sort de vos fils.
                      if (widget.pasInteresse != null)
                        _appli('oeil-barre', t('Pas intéressé'), () {
                          widget.pasInteresse!();
                          _fermer(t('Vous verrez moins de publications de ce type.'));
                        }),
                      if (widget.signaler != null)
                        _appli('drapeau', t('Signaler'), rouge: true, () {
                          Navigator.pop(context);
                          widget.signaler!();
                        }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ E09 enregistrer

/// `contenu` : la publication sur le serveur, enregistree dans une de mes collections.
Future<void> feuilleEnregistrer(BuildContext context, {String? contenu}) async {
  if (!Communaute.instance.enLigne) {
    bulle(context, t('Connectez-vous pour enregistrer dans vos collections.'), icone: 'profil');
    return;
  }
  if (contenu == null) {
    bulle(context, t('Cette publication n’est pas encore en ligne.'), icone: 'horloge');
    return;
  }
  await montrerFeuille<void>(
    context,
    titre: t('Enregistrer dans'),
    contenu: (f) => _Enregistrer(contenu: contenu),
  );
}

class _Enregistrer extends StatefulWidget {
  const _Enregistrer({required this.contenu});

  final String contenu;

  @override
  State<_Enregistrer> createState() => _EnregistrerState();
}

class _EnregistrerState extends State<_Enregistrer> {
  int? _choisie;

  // « Créer une collection » : la feuille devient un petit formulaire.
  bool _nouvelle = false;
  bool _secrete = false;
  final _nom = TextEditingController();

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Communaute.instance.chargerCollections().then((_) => mounted ? setState(() {}) : null);
  }

  Future<void> _creer() async {
    final nom = _nom.text.trim();
    final messager = ScaffoldMessenger.maybeOf(context);
    try {
      await Communaute.instance.creerCollection(nom, secrete: _secrete, contenu: widget.contenu);
      if (!mounted) return;
      Navigator.pop(context);
      if (messager != null) bulle(messager.context, t('Collection « {nom} » créée. La publication y est enregistrée.', {'nom': nom}));
    } on ErreurApi catch (e) {
      if (mounted) bulle(context, e.message, icone: 'alerte');
    } on ApiInjoignable {
      if (mounted) bulle(context, t('Aucune connexion. Réessayez dans un instant.'), icone: 'hors-ligne');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(duration: Durees.interface, child: _nouvelle ? _formulaire() : _liste());

  Widget _formulaire() => Padding(
    key: const ValueKey('nouvelle'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChampVerre(icone: 'collection', indice: t('Nom de la collection'), controleur: _nom, autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        MergeSemantics(
          child: Row(
            children: [
              Icone('cadenas', taille: 20, couleur: Couleurs.texte),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Secrète'),
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Couleurs.texte),
                    ),
                    Text(t('Vous seul la voyez.'), style: TextStyle(fontSize: 13, color: Couleurs.discret)),
                  ],
                ),
              ),
              Switch(value: _secrete, activeTrackColor: Couleurs.ocean, onChanged: (v) => setState(() => _secrete = v)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BoutonVerre(texte: t('Créer et enregistrer'), plein: true, onTap: _nom.text.trim().isEmpty ? null : _creer),
      ],
    ),
  );

  Widget _liste() {
    final collections = Communaute.instance.mesCollections;
    return ListView(
      key: const ValueKey('liste'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        for (var i = 0; i < collections.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              setState(() => _choisie = i);
              final messager = ScaffoldMessenger.maybeOf(context);
              final nom = collections[i].nom;
              final ok = await Communaute.instance.enregistrer(collections[i].id, widget.contenu) != null;
              await Future<void>.delayed(const Duration(milliseconds: 380));
              if (!mounted) return;
              Navigator.pop(context);
              if (messager != null) {
                bulle(messager.context, ok ? t('Enregistré dans « {nom} ».', {'nom': nom}) : t('Impossible d’enregistrer la publication. Réessayez.'), icone: ok ? 'coche' : 'alerte');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(width: 64, height: 64, child: CouvertureCollection(collections[i], rayon: 12, ecart: 1.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(collections[i].nom, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            if (collections[i].secrete) ...[Icone('cadenas', taille: 13, couleur: Couleurs.discret), const SizedBox(width: 3)],
                            Text(
                              collections[i].secrete
                                  ? t('{publications} · secrète', {'publications': nombrePublications(collections[i].nombre + (_choisie == i ? 1 : 0))})
                                  : nombrePublications(collections[i].nombre + (_choisie == i ? 1 : 0)),
                              style: TextStyle(fontSize: 12.5, color: Couleurs.discret),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedScale(
                    scale: _choisie == i ? 1 : 0,
                    duration: const Duration(milliseconds: 360),
                    curve: Courbes.ressort,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Couleurs.texte, shape: BoxShape.circle),
                      child: Icone('coche', taille: 16, couleur: Couleurs.surEncre),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _nouvelle = true),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Couleurs.surface.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
                  child: Icone('plus', taille: 26, couleur: Couleurs.texte),
                ),
                const SizedBox(width: 12),
                Text(t('Créer une collection'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ E08 telecharger

Future<void> feuilleTelecharger(
  BuildContext context, {
  required String photo,
  required String titre,
  required String appareil,
  required bool reel,
  int dureeSecondes = 0,
  String? contenu,
  String? video,
  String? videoHd,
  Map<String, ({int largeur, int hauteur})> tailles = const {},
}) => montrerFeuille<void>(
  context,
  titre: reel ? t('Télécharger le reel') : t('Télécharger la photo'),
  contenu: (_) => _Telecharger(photo: photo, titre: titre, appareil: appareil, reel: reel, duree: dureeSecondes, contenu: contenu, video: video, videoHd: videoHd, tailles: tailles),
);

class _Telecharger extends StatefulWidget {
  const _Telecharger({required this.photo, required this.titre, required this.appareil, required this.reel, required this.duree, this.contenu, this.video, this.videoHd, this.tailles = const {}});

  /// La video en 1080p, si le serveur l a faite.
  final String? videoHd;

  /// Les tailles servies d une photo (« 1080 », « 2160 », « 3840 ») et leurs dimensions.
  final Map<String, ({int largeur, int hauteur})> tailles;

  /// L identifiant de la publication sur le serveur (nul : demonstration ou fichier du telephone).
  final String? contenu;

  /// La video d un reel : un fichier du telephone ou une adresse du serveur.
  final String? video;
  final String photo;
  final String titre;
  final String appareil;
  final bool reel;
  final int duree;

  @override
  State<_Telecharger> createState() => _TelechargerState();
}

class _TelechargerState extends State<_Telecharger> {
  // Les choix d une publication du serveur, du plus net au plus leger : (cle, titre, detail).
  late final List<(String, String, String)> _choix = widget.reel
      ? [if (widget.videoHd != null) ('video-1080', t('Vidéo 1080p'), t('Full HD, la plus nette')), ('video', t('Vidéo 720p'), t('HD, plus légère'))]
      : [
          for (final (cle, nom) in [('3840', t('4K')), ('2160', t('Grande taille')), ('1080', t('Taille écran'))])
            if (widget.tailles[cle] case final d?) (cle, nom, t('{largeur} × {hauteur} px', {'largeur': _px(d.largeur), 'hauteur': _px(d.hauteur)})),
        ];

  // Par defaut : la plus grande que ce telephone affiche sans risque.
  late String? _taille = () {
    for (final (cle, _, _) in _choix) {
      if (_sure(cle)) return cle;
    }
    return _choix.isEmpty ? null : _choix.last.$1;
  }();

  static String _px(int n) => n >= 1000 ? '${n ~/ 1000} ${(n % 1000).toString().padLeft(3, '0')}' : '$n';

  bool _sure(String cle) {
    if (cle == 'video-1080') return !Capacites.instance.faible;
    final t = widget.tailles[cle];
    return t == null || Capacites.instance.peutAfficher(t.largeur, t.hauteur);
  }

  // Le fichier a copier, quand il est sur le telephone (mon envoi pas encore en ligne).
  String get _fichier => widget.reel ? (widget.video ?? '') : widget.photo;

  // Son vrai poids, lu sur le telephone (nul s il n y est pas).
  late final String? _poids = () {
    if (!_fichier.startsWith('/')) return null;
    try {
      final f = File(_fichier);
      if (!f.existsSync()) return null;
      final mo = f.lengthSync() / (1024 * 1024);
      return mo < 1 ? t('{n} Ko', {'n': (mo * 1024).ceil()}) : t('{n} Mo', {'n': mo.toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')});
    } catch (_) {
      return null;
    }
  }();

  @override
  Widget build(BuildContext context) {
    // Une publication du serveur : on ne connait pas son poids a l avance, on ne l invente pas.
    final serveur = widget.contenu != null;
    Widget choix(String? cle, String titre, String texte, {bool seul = false}) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: seul ? null : () => setState(() => _taille = cle),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Durees.interface,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _taille == cle ? Couleurs.texte : Couleurs.discret, width: _taille == cle ? 7 : 1.6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(texte, style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        Row(
          children: [
            SizedBox(width: 48, height: widget.reel ? 80 : 60, child: PhotoArrondie(widget.photo, rayon: 10)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.titre, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  Text(
                    widget.reel ? t('Vidéo MP4 · {duree}', {'duree': '${widget.duree ~/ 60}:${(widget.duree % 60).toString().padLeft(2, '0')}'}) : (serveur ? t('Photo WebP') : t('Photo')),
                    style: TextStyle(fontSize: 13, color: Couleurs.discret),
                  ),
                  Text(widget.reel ? t('{appareil} · son d’origine compris', {'appareil': widget.appareil}) : widget.appareil, style: TextStyle(fontSize: 13, color: Couleurs.discret)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Plaque(
          child: Column(
            children: [
              if (serveur && _choix.isNotEmpty)
                for (final (i, (cle, titre, detail)) in _choix.indexed) ...[if (i > 0) Divider(height: 1, indent: 46, color: Couleurs.filet), choix(cle, titre, detail, seul: _choix.length == 1)]
              else if (serveur)
                choix(null, widget.reel ? t('Vidéo') : t('Grande taille'), t('La meilleure qualité disponible'), seul: true)
              else
                // Un fichier du telephone : il part tel quel dans la galerie.
                choix(null, _poids == null ? t('Fichier d’origine') : t('Fichier d’origine · {poids}', {'poids': _poids}), t('Tel qu’il est sur ce téléphone'), seul: true),
            ],
          ),
        ),
        // Plus grand que ce que ce telephone affiche : on le dit avant, sans l interdire.
        if (serveur && _taille != null && !_sure(_taille!)) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icone('alerte', taille: 20, couleur: Couleurs.texte),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.reel
                      ? t('Votre téléphone risque de ne pas lire cette vidéo de façon fluide. Choisissez la vidéo 720p.')
                      : t('Cette photo fait {taille}. Votre téléphone risque de ne pas l’afficher. Choisissez une taille plus petite.', {'taille': _choix.firstWhere((c) => c.$1 == _taille).$3}),
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: Couleurs.texte),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(t('Pour un usage personnel.'), style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
        const SizedBox(height: 14),
        BoutonVerre(
          texte: t('Télécharger'),
          icone: 'telecharger',
          plein: true,
          onTap: () async {
            final messager = ScaffoldMessenger.maybeOf(context);
            Navigator.pop(context);
            if (widget.reel && widget.video == null) {
              // Un reel sans video (pas encore arrivee) : rien a enregistrer.
              if (messager != null) bulle(messager.context, t('Cette vidéo n’est pas encore disponible.'), icone: 'telecharger');
              return;
            }
            if (messager != null && serveur) bulle(messager.context, widget.reel ? t('Téléchargement de la vidéo…') : t('Téléchargement de la photo…'), icone: 'telecharger');
            // Sa barre avance dans la notification du telephone et dans Mes envois (Telechargements).
            final d = await Telechargements.instance.lancer(
              titre: widget.titre,
              source: widget.reel ? widget.video! : widget.photo,
              vignette: widget.photo,
              contenu: widget.contenu,
              video: widget.reel,
              taille: _taille,
            );
            if (messager == null || !messager.mounted) return;
            bulle(messager.context, Telechargements.messageDe(d), icone: d.etat == EtatTelechargement.ok ? 'coche' : 'alerte');
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ E06 reactions

const reactionsUsw = ['❤️', '🤩', '🧳', '🙏'];

Future<void> feuilleReactions(BuildContext context, {required String total, String? contenu}) => montrerFeuille<void>(
  context,
  titre: t('{total} réactions', {'total': total}),
  contenu: (_) => _Reactions(contenu: contenu),
);

class _Reactions extends StatefulWidget {
  const _Reactions({this.contenu});

  /// La publication sur le serveur : qui a reagi (nul : pas encore en ligne, personne).
  final String? contenu;

  @override
  State<_Reactions> createState() => _ReactionsState();
}

class _ReactionsState extends State<_Reactions> {
  /// La reaction choisie (sa cle : coeur, waouh…), ou toutes.
  String? _filtre;

  /// Abonne ou non, par pseudo.
  final _suivis = <String, bool>{};

  /// Le serveur : (nom, pseudo, emoji, abonne, avatar), et le total de chaque reaction.
  List<(String, String, String, bool, String?)>? _serveur;
  Map<String, int> _totaux = const {};
  int _total = 0;

  /// La page suivante (nulle : tout est la), et un chargement en cours.
  String? _suivant;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    if (widget.contenu != null) _charger();
  }

  // La premiere page (ou la suite, `suite`) des membres de la reaction choisie.
  Future<void> _charger({bool suite = false}) async {
    if (_enCours || (suite && _suivant == null)) return;
    final filtre = _filtre;
    _enCours = true;
    final r = await Communaute.instance.quiAReagi(widget.contenu!, type: filtre, curseur: suite ? _suivant : null);
    // Une autre pastille choisie entre-temps : sa page a elle arrive.
    if (!mounted || filtre != _filtre) return;
    _enCours = false;
    if (r == null) {
      if (!suite) setState(() => _serveur = const []);
      bulle(context, t('Impossible de charger les réactions. Réessayez.'), icone: 'hors-ligne');
      return;
    }
    setState(() {
      _totaux = r.totaux;
      _total = r.total;
      _suivant = r.suivant;
      final page = [for (final (pseudo, nom, avatar, type, abonne) in r.membres) (nom, pseudo, reactions[type] ?? '❤️', abonne, avatar)];
      _serveur = suite ? [...?_serveur, ...page] : page;
      for (final m in page) {
        _suivis[m.$2] = m.$4 || Communaute.instance.suit(m.$2);
      }
    });
  }

  // Une pastille : le serveur donne les membres de cette reaction.
  void _choisir(String? cle) {
    if (cle == _filtre) return;
    setState(() {
      _filtre = cle;
      _serveur = null;
      _suivant = null;
      _enCours = false;
    });
    if (widget.contenu != null) _charger();
  }

  Future<void> _suivre(String pseudo) async {
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour vous abonner.'), icone: 'profil');
      return;
    }
    final oui = !(_suivis[pseudo] ?? false);
    setState(() => _suivis[pseudo] = oui);
    if (await Communaute.instance.suivre(pseudo, oui) == null && mounted) {
      setState(() => _suivis[pseudo] = !oui);
      bulle(context, oui ? t('Impossible de vous abonner. Réessayez.') : t('Impossible de vous désabonner. Réessayez.'), icone: 'alerte');
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _serveur ?? const <(String, String, String, bool, String?)>[];
    final pastilles = <(String?, String)>[
      (null, t('Toutes {nombre}', {'nombre': nombreCourt(_total)})),
      for (final e in reactions.entries)
        if ((_totaux[e.key] ?? 0) > 0) (e.key, '${e.value} ${nombreCourt(_totaux[e.key]!)}'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (cle, n) in pastilles) ...[Pastille(texte: n, retenue: _filtre == cle, onTap: () => _choisir(cle)), const SizedBox(width: 8)],
            ],
          ),
        ),
        if (widget.contenu == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Text(t('Personne n’a encore réagi.'), style: Textes.discret, textAlign: TextAlign.center),
          )
        else if (_serveur == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Text(t('Chargement des réactions…'), style: Textes.discret, textAlign: TextAlign.center),
          ),
        Flexible(
          // Pres du bas de la liste : la page suivante arrive.
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) _charger(suite: true);
              return false;
            },
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                for (final (nom, pseudo, emoji, _, avatar) in liste)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Avatar(nom: nom, taille: 46, photo: avatar),
                            Positioned(right: -4, bottom: -4, child: Text(emoji, style: const TextStyle(fontSize: 18))),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(pseudo, style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                            ],
                          ),
                        ),
                        if (pseudo != Session.instance.nomUtilisateur) BoutonAbonner(abonne: _suivis[pseudo] ?? false, onTap: () => _suivre(pseudo)),
                      ],
                    ),
                  ),
                // La liste tient sans defiler : la suite se demande au toucher.
                if (_suivant != null)
                  Center(
                    child: TextButton(
                      onPressed: () => _charger(suite: true),
                      child: Text(
                        t('Voir plus'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: Couleurs.texte),
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

// ------------------------------------------------------------ qui a vu

/// Qui a vu ma publication : seul son auteur ouvre cette feuille (le serveur refuse les autres).
/// Les membres, les plus recents d abord ; les visiteurs sans compte, seulement leur nombre.
Future<void> feuilleSpectateurs(BuildContext context, {required String contenu, required int total}) => montrerFeuille<void>(
  context,
  titre: vuesLisibles(total),
  titreVivant: () => vuesLisibles(Vues.instance.nombre(contenu, total)),
  suit: Vues.instance,
  contenu: (_) => _Spectateurs(contenu: contenu, page: context),
);

class _Spectateurs extends StatefulWidget {
  const _Spectateurs({required this.contenu, required this.page});

  final String contenu;

  /// La page sous la feuille : un membre touche s y ouvre.
  final BuildContext page;

  @override
  State<_Spectateurs> createState() => _SpectateursState();
}

class _SpectateursState extends State<_Spectateurs> {
  ({int total, int sansCompte, List<({String pseudo, String nom, String? avatar, DateTime? vuLe})> membres})? _liste;
  bool _echec = false;

  @override
  void initState() {
    super.initState();
    Vues.instance.spectateurs(widget.contenu).then((r) {
      if (mounted) setState(() => r == null ? _echec = true : _liste = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    final message = _echec
        ? t('Impossible de charger les vues. Réessayez.')
        : l == null
        ? t('Chargement…')
        : l.membres.isEmpty && l.sansCompte == 0
        ? t('Personne n’a encore vu cette publication.')
        : null;
    if (message != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Text(message, style: Textes.discret, textAlign: TextAlign.center),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(t('Vous seul voyez qui a vu votre publication.'), style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
              ),
              for (final m in l!.membres)
                Appuyable(
                  semantique: m.nom,
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.page.mounted) widget.page.push(ici(widget.page, 'createur/${m.pseudo}'));
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Avatar(nom: m.nom, taille: 46, photo: m.avatar),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.nom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(m.pseudo, style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                            ],
                          ),
                        ),
                        if (m.vuLe != null) Text(ilYA(m.vuLe!), style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                      ],
                    ),
                  ),
                ),
              if (l.sansCompte > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.membres.isEmpty ? tn(l.sansCompte, '{n} visiteur sans compte', '{n} visiteurs sans compte') : tn(l.sansCompte, 'Et {n} visiteur sans compte', 'Et {n} visiteurs sans compte'),
                    style: Textes.discret,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Le texte d une feuille de confirmation simple.
Widget texteFeuille(String texte) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
  child: Text(texte, style: Textes.discret),
);

// ------------------------------------------------------------ E22 signaler

/// Un motif a cocher : un intitule, parfois une precision dessous (deja traduits).
typedef Motif = (String, String?);

/// Les motifs envoyes au serveur, tels quels.
const motifsSignalement = <Motif>[
  ('Image générée ou retouchée par IA', null),
  ('Pas pris à cet endroit', 'Le lieu indiqué est faux'),
  ("Ce n'est pas son auteur", "Le contenu appartient à quelqu'un d'autre"),
  ('Contenu choquant ou violent', null),
  ('Harcèlement ou propos haineux', null),
  ('Spam ou arnaque', null),
];

/// Les memes, a l ecran : le serveur recoit le texte francais de [motifsSignalement].
List<Motif> get _motifsSignalementAffiches => [
  (t('Image générée ou retouchée par IA'), null),
  (t('Pas pris à cet endroit'), t('Le lieu indiqué est faux')),
  (t('Ce n’est pas son auteur'), t('Le contenu appartient à quelqu’un d’autre')),
  (t('Contenu choquant ou violent'), null),
  (t('Harcèlement ou propos haineux'), null),
  (t('Spam ou arnaque'), null),
];

/// `quoi` : photo, reel ou profil.
/// `id` : la publication (son identifiant) ou le profil (son pseudo) sur le serveur.
/// Sans compte, ou pour une publication pas encore en ligne, la feuille ne s ouvre pas.
Future<void> feuilleSignaler(BuildContext context, {required String quoi, String? id}) async {
  if (!Communaute.instance.enLigne) {
    bulle(context, t('Connectez-vous pour signaler.'), icone: 'profil');
    return;
  }
  if (id == null) {
    bulle(context, t('Cette publication n’est pas encore en ligne.'), icone: 'horloge');
    return;
  }
  await montrerFeuille<void>(
    context,
    titre: switch (quoi) {
      'reel' => t('Signaler ce reel'),
      'profil' => t('Signaler ce profil'),
      _ => t('Signaler cette photo'),
    },
    contenu: (f) => _Signaler(cible: quoi == 'profil' ? 'utilisateur' : 'contenu', id: id),
  );
}

class _Signaler extends StatefulWidget {
  const _Signaler({required this.cible, required this.id});

  final String cible;
  final String id;

  @override
  State<_Signaler> createState() => _SignalerState();
}

class _SignalerState extends State<_Signaler> {
  int? _motif;
  final _precision = TextEditingController();

  @override
  void dispose() {
    _precision.dispose();
    super.dispose();
  }

  // Le bouton reste en bas de la feuille ; les motifs defilent au besoin.
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('Votre signalement reste anonyme. L’équipe le vérifie sous 24 h.'), style: Textes.petit),
              const SizedBox(height: 12),
              ListeMotifs(motifs: _motifsSignalementAffiches, choisi: _motif, onChoisi: (i) => setState(() => _motif = i)),
              const SizedBox(height: 12),
              ChampVerre(icone: 'crayon', indice: t('Ajoutez une précision (facultatif)'), controleur: _precision),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/document/regles');
                  },
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 2), minimumSize: const Size(0, 36)),
                  child: Text.rich(_lienRegles()),
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: BoutonVerre(
          texte: t('Envoyer le signalement'),
          teinte: TeinteVerre.rouge,
          onTap: _motif == null
              ? null
              : () async {
                  final messager = ScaffoldMessenger.maybeOf(context);
                  final motif = motifsSignalement[_motif!].$1;
                  final precision = _precision.text.trim();
                  Navigator.pop(context);
                  final message = await Communaute.instance.signaler(widget.cible, widget.id, motif, precision: precision.isEmpty ? null : precision);
                  if (messager != null && messager.mounted) bulle(messager.context, message, icone: 'drapeau');
                },
        ),
      ),
    ],
  );

  // « Voir les règles communautaires. » : une seule phrase a traduire, le lien souligne dedans.
  TextSpan _lienRegles() {
    final morceaux = t('Voir les {regles}.').split('{regles}');
    return TextSpan(
      text: morceaux.first,
      style: TextStyle(fontSize: 13.5, color: Couleurs.discret),
      children: [
        TextSpan(
          text: t('règles communautaires'),
          style: TextStyle(fontWeight: FontWeight.w600, color: Couleurs.texte, decoration: TextDecoration.underline),
        ),
        if (morceaux.length > 1) TextSpan(text: morceaux.sublist(1).join()),
      ],
    );
  }
}

/// Les motifs a cocher (signaler, refuser en moderation) : une plaque de
/// verre, un rond qui se remplit d encre avec un ressort.
class ListeMotifs extends StatelessWidget {
  const ListeMotifs({super.key, required this.motifs, required this.choisi, required this.onChoisi});

  final List<Motif> motifs;
  final int? choisi;
  final ValueChanged<int> onChoisi;

  @override
  Widget build(BuildContext context) => Plaque(
    child: Column(
      children: [
        for (var i = 0; i < motifs.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 0.7, indent: 48, color: Couleurs.filet),
          Semantics(
            selected: choisi == i,
            inMutuallyExclusiveGroup: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChoisi(i),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Courbes.interface,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: choisi == i ? Couleurs.texte : Couleurs.trait, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        scale: choisi == i ? 1 : 0,
                        duration: const Duration(milliseconds: 360),
                        curve: Courbes.ressort,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(color: Couleurs.texte, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(motifs[i].$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          if (motifs[i].$2 != null) Text(motifs[i].$2!, style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// La couverture d une collection : sa premiere photo en grand, deux autres a
/// cote. Une collection neuve, encore vide, montre son icone.
class CouvertureCollection extends StatelessWidget {
  const CouvertureCollection(this.collection, {super.key, this.rayon = 16, this.ecart = 2});

  final Collection collection;
  final double rayon;
  final double ecart;

  // Secrete et verrouillee : ses photos ne se montrent pas, le cadenas a leur place.
  @override
  Widget build(BuildContext context) {
    if (!collection.secrete) return _construire(context);
    return ListenableBuilder(listenable: Verrou.instance, builder: (context, _) => _construire(context));
  }

  Widget _construire(BuildContext context) {
    final photos = collection.photos;
    if (collection.secrete && !Verrou.instance.ouvert) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Couleurs.photoVide, borderRadius: BorderRadius.circular(rayon)),
        child: Icone('cadenas', taille: 26, couleur: Couleurs.discret),
      );
    }
    if (photos.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Couleurs.photoVide, borderRadius: BorderRadius.circular(rayon)),
        child: Icone('collection', taille: 26, couleur: Couleurs.discret),
      );
    }
    Widget photo(int n) => Photo(photos[n % photos.length]);
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: photo(0)),
          SizedBox(width: ecart),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: photo(1)),
                SizedBox(height: ecart),
                Expanded(child: photo(2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
