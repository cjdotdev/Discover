// E05 Photo : la photo en grand, ce qu on peut en faire (aimer, commenter,
// partager, telecharger l original, Y aller), la fiche de capture qui la rend
// verifiable (lieu GPS, telephone, date, et d ou vient chaque information),
// son auteur, les commentaires, puis d autres lieux. Le lot 2 branchera
// GET /api/v1/publications/{id} ; les commentaires et les feuilles (E07 a E10)
// viendront au lot suivant.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../outils/partage.dart';
import '../outils/chemins.dart';
import '../donnees/vues.dart';
import '../donnees/modeles.dart';
import '../donnees/session.dart';
import '../donnees/communaute.dart';
import '../donnees/catalogue.dart';
import '../donnees/lieux_enregistres.dart' show nombrePublications;
import '../outils/langue.dart';
import '../outils/reseau.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/feuilles.dart';
import '../widgets/icone.dart';
import '../widgets/mouvement.dart';
import '../widgets/options.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';
import 'visionneuse.dart';

class EcranPhoto extends StatefulWidget {
  const EcranPhoto({super.key, required this.lieu, required this.index, this.commentaires = false});

  final Lieu lieu;
  final int index;

  /// Ouvrir les commentaires des l arrivee (une notification de commentaire
  /// ou de mention y mene).
  final bool commentaires;

  @override
  State<EcranPhoto> createState() => _EcranPhotoState();
}

class _EcranPhotoState extends State<EcranPhoto> {
  // La route n ouvre cette page que si le lieu a des publications (app.dart).
  late final Publication _publication = () {
    final liste = publicationsDe(widget.lieu);
    return liste[widget.index.clamp(0, liste.length - 1)];
  }();
  late final DetailPublication _detail = detailDuServeur(widget.lieu, _publication);

  /// La publication telle que le catalogue la connait maintenant (mon titre retouche) ; les
  /// compteurs, eux, restent ceux de l arrivee (_detail), que mes gestes ajustent.
  Publication get _aJour => (_publication.id == null ? null : Catalogue.instance.publication(_publication.id!)) ?? _publication;

  /// Le titre et la legende a montrer : ceux que je viens de retoucher, des le toucher.
  ({String titre, String legende}) get _texte {
    final r = Catalogue.instance.retouche(_publication.id);
    if (r != null) return (titre: r.titre.isNotEmpty ? r.titre : widget.lieu.nom, legende: r.legende);
    final d = detailDuServeur(widget.lieu, _aJour);
    return (titre: d.titre, legende: d.legende);
  }

  void _catalogueChange() {
    if (mounted) setState(() {});
  }

  /// Sur le serveur : ma reaction connue, et les commentaires du haut.
  bool get _serveur => _publication.id != null;
  late final bool _aimeAuDepart = _serveur ? Communaute.instance.reactionSur(_publication.id!, duServeur: _publication.maReaction) != null : false;
  late bool _aime = _aimeAuDepart;
  late bool _abonne = Communaute.instance.suit(_publication.auteur);
  late final bool _abonneAuDepart = _abonne;

  /// Les abonnes de l auteur, d apres son profil (GET utilisateurs/{nom}), sans mon geste ; nul tant qu on ne sait pas.
  late int? _abonnes = Catalogue.instance.createurConnu(_pseudoAuteur)?.abonnes;
  List<CommentaireServeur>? _premiers;
  String get _pseudoAuteur => _publication.auteur.replaceFirst('@', '');
  bool get _maPublication => _pseudoAuteur == Session.instance.nomUtilisateur;

  // Le temps passe sur la photo : une vue au-dela de 2 s (le serveur en decide).
  final _regard = Stopwatch()..start();

  /// Le nombre de commentaires : tenu a jour par chaque ajout ou suppression (Communaute).
  int get _nbCommentaires => Communaute.instance.nombreCommentaires(_publication.id, _detail.commentaires);
  int _versionCommentaires = 0;

  // Un commentaire ajoute ou retire dans la feuille : la page suit tout de suite (le retire part
  // des premiers commentaires montres), puis le serveur redonne les premiers.
  void _commentairesChangent() {
    final id = _publication.id;
    if (id == null || !mounted) return;
    final v = Communaute.instance.versionCommentaires(id);
    if (v == _versionCommentaires) return;
    _versionCommentaires = v;
    setState(() => _premiers = _premiers?.where((c) => !Communaute.instance.commentairesRetires.contains(c.id)).toList());
    Communaute.instance.commentaires(id).then((c) {
      if (mounted && c != null) setState(() => _premiers = c.take(2).toList());
    });
  }

  /// Les deux commentaires montres : ceux que je viens d envoyer d abord (tout de suite, sans
  /// attendre le serveur), puis les premiers du serveur ; sans ceux que j ai retires.
  List<CommentaireServeur> get _montres {
    final id = _publication.id;
    final miens = id == null ? const <CommentaireServeur>[] : Communaute.instance.envoyes(id);
    final premiers = _premiers ?? const <CommentaireServeur>[];
    final ids = {for (final c in premiers) c.id};
    return [
      ...premiers.where((c) => c.epingle),
      ...miens.where((c) => !ids.contains(c.id)),
      ...premiers.where((c) => !c.epingle),
    ].where((c) => !Communaute.instance.commentairesRetires.contains(c.id)).take(2).toList();
  }

  /// Les vues : le nombre le plus recent du serveur, qui suit pendant que la page est ouverte.
  int get _vues => Vues.instance.nombre(_publication.id, _detail.vues);

  Timer? _maVue;

  void _vuesChangent() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _maVue?.cancel();
    Communaute.instance.removeListener(_reactionsChangent);
    Vues.instance.removeListener(_vuesChangent);
    Communaute.instance.removeListener(_commentairesChangent);
    Catalogue.instance.removeListener(_catalogueChange);
    final id = _publication.id;
    if (id != null && !_maPublication) Vues.instance.noter(id, _regard.elapsed);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Catalogue.instance.addListener(_catalogueChange);
    if (widget.commentaires) {
      // Apres l entree de la page, pour que la feuille monte sur la photo.
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _commentaires();
      });
    }
    if (_serveur) {
      // Ma publication : le nombre a jour tout de suite. Celle d un autre : apres 2 s, ma vue
      // part sans attendre le paquet, et le serveur rend le nombre qui la compte.
      final id = _publication.id!;
      Vues.instance.addListener(_vuesChangent);
      Communaute.instance.addListener(_reactionsChangent);
      if (_maPublication) {
        Vues.instance.actualiser(id);
      } else {
        _maVue = Timer(const Duration(milliseconds: 2100), () {
          Vues.instance.noter(id, _regard.elapsed);
          Vues.instance.envoyer();
        });
      }
      Communaute.instance.connaitreCommentaires(_publication.id!, _detail.commentaires);
      _versionCommentaires = Communaute.instance.versionCommentaires(_publication.id!);
      Communaute.instance.addListener(_commentairesChangent);
      Communaute.instance.commentaires(_publication.id!).then((c) {
        if (mounted && c != null) setState(() => _premiers = c.take(2).toList());
      });
    }
    // Toujours redemande : le nombre garde en memoire peut dater d avant un abonnement.
    if (_pseudoAuteur.isNotEmpty) {
      Catalogue.instance.chargerCreateur(_pseudoAuteur).then((c) {
        if (mounted && c != null) setState(() => _abonnes = c.abonnes);
      });
    }
  }

  // « 1 abonné », « 12 abonnés » : le nombre du serveur, plus mon geste depuis l arrivee.
  String? get _abonnesLisibles {
    final n = _abonnes;
    if (n == null) return null;
    final total = n + (_abonne && !_abonneAuDepart ? 1 : 0) - (!_abonne && _abonneAuDepart ? 1 : 0);
    return total <= 1 ? tn(total < 0 ? 0 : total, '{n} abonné', '{n} abonnés') : t('{n} abonnés', {'n': nombreCourt(total)});
  }

  void _commentaires() => feuilleCommentaires(context, nombre: _detail.commentaires, auteur: _detail.createur, contenu: _publication.id, monContenu: _maPublication);

  /// La video de la page : la 1080p, sauf en economie de donnees.
  String? get _videoMontree => !Reseau.instance.photosLegeres && _publication.videoHd != null ? _publication.videoHd : _publication.video;

  Future<void> _aimer() async {
    // Pas encore en ligne, ou sans compte : rien ne change a l ecran.
    if (!_serveur) {
      bulle(context, t('Cette publication est en cours d’envoi. Vous pourrez y réagir une fois qu’elle sera en ligne.'), icone: 'horloge');
      return;
    }
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour réagir.'), icone: 'profil');
      return;
    }
    final oui = !_aime;
    setState(() => _aime = oui);
    if (!await Communaute.instance.reagir(_publication.id, oui ? 'coeur' : null) && mounted) {
      setState(() => _aime = !oui);
      bulle(context, t('Impossible de réagir à cette publication.'), icone: 'alerte');
    }
  }

  Future<void> _suivre() async {
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour vous abonner.'), icone: 'profil');
      return;
    }
    final oui = !_abonne;
    setState(() => _abonne = oui);
    final n = await Communaute.instance.suivre(_pseudoAuteur, oui);
    if (!mounted) return;
    if (n == null) {
      setState(() => _abonne = !oui);
      bulle(context, oui ? t('Impossible de vous abonner. Réessayez.') : t('Impossible de vous désabonner. Réessayez.'), icone: 'alerte');
      return;
    }
    // Le serveur donne le nouveau nombre, mon geste compris : il remplace le calcul.
    if (n >= 0) setState(() => _abonnes = n - (oui && !_abonneAuDepart ? 1 : 0) + (!oui && _abonneAuDepart ? 1 : 0));
  }

  int get _jaime => Communaute.instance.nombreReactions(_publication.id, duServeur: _detail.jaime, moiDuServeur: _publication.maReaction != null);

  // Le nombre exact de reactions arrive du serveur apres mon geste : la page le prend.
  void _reactionsChangent() {
    if (mounted) setState(() {});
  }

  void _telecharger() => feuilleTelecharger(
    context,
    photo: _publication.grande ?? _publication.photo,
    titre: _texte.titre,
    appareil: _publication.appareil,
    reel: _publication.reel,
    dureeSecondes: _publication.dureeReel ?? 0,
    contenu: _publication.id,
    video: _publication.video,
    videoHd: _publication.videoHd,
    tailles: _publication.tailles,
  );

  void _partager() => feuillePartager(
    context,
    titre: _texte.titre,
    sousTitre: '${_publication.auteur} · ${widget.lieu.nom}',
    auteur: _publication.nomAuteur ?? _pseudoAuteur,
    avatarAuteur: _maPublication ? (Session.instance.photo ?? Session.instance.avatar) : _publication.avatarAuteur,
    photo: _publication.photo,
    lien: _publication.id == null ? '$domainePublic/l/${widget.lieu.id}' : '$domainePublic/p/${_publication.id}',
    telecharger: _telecharger,
    enregistrer: () => feuilleEnregistrer(context, contenu: _publication.id),
    // Ma publication, ou une pas encore en ligne : ni signalement, ni « Pas intéressé ».
    signaler: _maPublication || _publication.id == null ? null : () => feuilleSignaler(context, quoi: _publication.reel ? 'reel' : 'photo', id: _publication.id),
    pasInteresse: _maPublication || _publication.id == null
        ? null
        : () {
            Catalogue.instance.pasInteresse(_publication.id!);
            if (context.canPop()) context.pop();
          },
    contenu: _publication.id,
  );

  // Enregistrer, partager, telecharger, voir moins, signaler ; la mienne se supprime, et la page se ferme.
  void _options() => optionsPublication(
    context,
    _aJour,
    lieu: widget.lieu,
    titre: _texte.titre,
    apresSuppression: () {
      if (mounted) context.canPop() ? context.pop() : context.go('/accueil');
    },
  );

  Future<void> _yAller() => yAller(context, widget.lieu);

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(taille.width);
    final ratio = ratioDe(_publication.photo);
    // La photo ne prend pas plus des deux tiers de l ecran : les actions et
    // le titre restent visibles sans defiler.
    final hauteurPhoto = (((taille.width - 16) / ratio)).clamp(0.0, taille.height * 0.62);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, haut + 4, 0, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Monte(
            distance: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: hauteurPhoto,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Toucher la photo l ouvre en plein ecran, dans son format.
                      GestureDetector(
                        // Un reel se lit ; une photo s ouvre en plein ecran, dans sa grande taille.
                        onTap: () => _publication.video != null
                            // La meme video que celle qui joue deja (gardee sur le telephone) : elle part aussitot.
                            ? ouvrirLecture(context, _videoMontree!, affiche: _publication.grande ?? _publication.photo, replis: [?_publication.video])
                            : ouvrirVisionneuse(context, _publication.grande ?? _publication.photo, contenu: _publication.id, tresGrande: _publication.tresGrande, tailles: _publication.tailles),
                        child: Semantics(
                          button: true,
                          label: _publication.video != null ? t('Lire le reel') : t('Voir la photo en plein écran'),
                          // Économiser les données : la version légère ; le plein écran garde la grande.
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Photo(Reseau.instance.photosLegeres ? _publication.photo : (_publication.grande ?? _publication.photo)),
                              // Une video s y lit deja, sans le son, en boucle ; la toucher la lit en grand, avec le son.
                              if (_publication.video != null) VideoMuette(_videoMontree!, prioritaire: true, replis: [?_publication.video, ?_publication.videoApercu]),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            RondVerre(
                              icone: 'retour',
                              semantique: t('Retour'),
                              surPhoto: true,
                              lisible: true,
                              // Sur la photo, l encre reste noire, de jour comme de nuit.
                              encre: _encrePhoto,
                              onTap: () => context.canPop() ? context.pop() : context.go(ici(context, 'lieu/${widget.lieu.id}')),
                            ),
                            const Spacer(),
                            RondVerre(icone: 'plus-points', semantique: t('Plus d’options'), surPhoto: true, lisible: true, encre: _encrePhoto, onTap: () => _options()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Les actions : sur la photo, ce qu on fait d un geste.
          Monte(
            delai: const Duration(milliseconds: 250),
            child: Padding(
              padding: EdgeInsets.fromLTRB(marge - 8, 10, marge, 2),
              child: Row(
                children: [
                  // Les actions se resserrent si le texte est agrandi, Y aller garde sa place.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          _Action(
                            icone: _aime ? 'coeur-plein' : 'coeur',
                            couleur: _aime ? Couleurs.erreur : null,
                            compte: nombreCourt(_jaime),
                            semantique: _aime ? t('Je n’aime plus') : t('J’aime'),
                            onTap: _aimer,
                          ),
                          _Action(icone: 'commentaire', compte: '$_nbCommentaires', semantique: t('Commentaires'), onTap: _commentaires),
                          _Action(icone: 'partager', semantique: t('Partager'), onTap: () => _partager()),
                          _Action(icone: 'telecharger', semantique: t('Télécharger l’original'), onTap: () => _telecharger()),
                          // Toujours la, meme a 0 ; l auteur, lui seul, voit qui a vu en le touchant.
                          if (_serveur)
                            _Action(
                              icone: 'oeil',
                              compte: nombreCourt(_vues),
                              semantique: _maPublication ? t('{vues}, voir qui a vu', {'vues': vuesLisibles(_vues)}) : vuesLisibles(_vues),
                              onTap: _maPublication ? () => feuilleSpectateurs(context, contenu: _publication.id!, total: _vues) : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.lieu.situe) ...[const SizedBox(width: 8), BoutonVerre(texte: t('Y aller'), plein: true, large: false, widgetIcone: const Icone('y-aller', taille: 20), onTap: _yAller)],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 8, marge, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Titre(
                  _texte.titre,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.48, height: 1.15, color: Couleurs.texte),
                ),
                const SizedBox(height: 6),
                Monte(
                  delai: const Duration(milliseconds: 450),
                  child: Text(_texte.legende, style: TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texte.withValues(alpha: 0.82))),
                ),
                const SizedBox(height: 18),
                Monte(
                  delai: const Duration(milliseconds: 550),
                  child: _Fiche(lieu: widget.lieu, publication: _publication, detail: _detail),
                ),
                const SizedBox(height: 18),
                Monte(
                  delai: const Duration(milliseconds: 650),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push(ici(context, 'createur/${_publication.auteur.replaceFirst('@', '')}')),
                    child: Row(
                      children: [
                        // Sa photo de profil (la mienne, si c est ma publication), sinon ses initiales.
                        if (_maPublication) const AvatarMoi() else Avatar(nom: _detail.createur, photo: _publication.avatarAuteur),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_detail.createur, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                              if (_abonnesLisibles != null) Text(_abonnesLisibles!, style: TextStyle(fontSize: 13, color: Couleurs.discret)),
                            ],
                          ),
                        ),
                        if (!_maPublication) BoutonAbonner(abonne: _abonne, onTap: _suivre),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(tn(_nbCommentaires, '{n} commentaire', '{n} commentaires'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                // Les deux premiers commentaires.
                for (final c in _montres) _Commentaire(nom: c.nom, texte: c.texte, epingle: c.epingle, photo: c.avatar),
                const SizedBox(height: 4),
                Appuyable(
                  semantique: t('Ajouter un commentaire'),
                  onTap: _commentaires,
                  child: Verre(
                    rayon: 24,
                    child: SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(t('Ajouter un commentaire, @mentionner…'), style: TextStyle(fontSize: 14, color: Couleurs.discret)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(t('D’autres lieux'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _Suite(lieu: widget.lieu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icone, required this.semantique, this.onTap, this.compte, this.couleur});

  final String icone;
  final String semantique;

  /// Nul : un simple compteur (les vues).
  final VoidCallback? onTap;
  final String? compte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Appuyable(
    semantique: semantique,
    onTap: onTap,
    child: SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icone(icone, taille: 24, couleur: couleur ?? Couleurs.texte),
            if (compte != null) ...[
              const SizedBox(width: 5),
              Text(
                compte!,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: couleur ?? Couleurs.texte),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// La fiche de capture : ce qui rend la photo verifiable, et d ou vient
/// chaque information (le fichier, ou l auteur).
class _Fiche extends StatelessWidget {
  const _Fiche({required this.lieu, required this.publication, required this.detail});

  final Lieu lieu;
  final Publication publication;
  final DetailPublication detail;

  // D ou vient l information, telle que le serveur l a notee ; nul s il ne l a pas dit.
  String? _origine(String champ) => switch (publication.origines[champ]) {
    'exif' => t('Métadonnées du fichier'),
    'appareil' => t('Appareil photo, à la prise'),
    'declaree' => t('Indiqué par l’auteur'),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final position = _origine('position');
    final gps = publication.latitude != null && publication.longitude != null && publication.origines['position'] != 'declaree' ? ' · ${detail.gps}' : '';
    return Plaque(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t('Informations de capture'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              BadgeCapture(verifie: publication.verifiee, court: true),
            ],
          ),
          const SizedBox(height: 6),
          _Ligne(icone: 'lieu', titre: t('Lieu'), valeur: lieu.region.isEmpty ? lieu.nom : '${lieu.nom}, ${lieu.region}', origine: position == null ? null : '$position$gps', premiere: true),
          _Ligne(icone: 'telephone', titre: t('Téléphone'), valeur: publication.appareil, origine: _origine('modele')),
          _Ligne(icone: 'calendrier', titre: t('Prise le'), valeur: detail.priseLe, origine: _origine('date')),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.titre, required this.valeur, required this.origine, this.premiere = false});

  final String icone;
  final String titre;
  final String valeur;
  final String? origine;
  final bool premiere;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: premiere ? null : Border(top: BorderSide(color: Couleurs.filet)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icone(icone, taille: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                const SizedBox(height: 1),
                Text(valeur, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (origine != null) Text(origine!, style: TextStyle(fontSize: 12, color: Couleurs.discret)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Commentaire extends StatelessWidget {
  const _Commentaire({required this.nom, required this.texte, this.epingle = false, this.photo});

  final String? photo;

  final String nom;
  final String texte;
  final bool epingle;

  @override
  Widget build(BuildContext context) {
    // Les @mentions en ocean.
    final morceaux = <TextSpan>[];
    texte.splitMapJoin(
      RegExp(r'@[\w.]+'),
      onMatch: (m) {
        morceaux.add(
          TextSpan(
            text: m[0],
            style: TextStyle(fontWeight: FontWeight.w600, color: Couleurs.ocean),
          ),
        );
        return '';
      },
      onNonMatch: (t) {
        morceaux.add(TextSpan(text: t));
        return '';
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(nom: nom, taille: 34, photo: photo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (epingle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      t('Épinglé par l’auteur'),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Couleurs.ocean),
                    ),
                  ),
                // Le nom sur sa ligne, le commentaire dessous.
                Text(nom, style: Textes.corps.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: morceaux), style: Textes.corps.copyWith(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// D autres lieux, en piles comme a l accueil.
class _Suite extends StatelessWidget {
  const _Suite({required this.lieu});

  final Lieu lieu;

  @override
  Widget build(BuildContext context) {
    // Les plus proches de ce lieu d abord (a vol d oiseau), s il a une position.
    final autres = Catalogue.instance.lieux.where((l) => l.id != lieu.id && l.photos.isNotEmpty).toList();
    if (lieu.situe) {
      double d(Lieu l) => l.situe ? Geolocator.distanceBetween(lieu.latitude, lieu.longitude, l.latitude, l.longitude) : double.infinity;
      autres.sort((a, b) => d(a).compareTo(d(b)));
    }
    if (autres.length > 4) autres.removeRange(4, autres.length);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < 2; c++) ...[
          if (c > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (var i = c; i < autres.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Appuyable(
                      semantique: autres[i].nom,
                      onTap: () => context.push(ici(context, 'lieu/${autres[i].id}')),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(aspectRatio: autres[i].ratio, child: PhotoArrondie(autres[i].photos.first)),
                          const SizedBox(height: 7),
                          Text(autres[i].nom, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25)),
                          Text(nombrePublications(autres[i].nombre), style: TextStyle(fontSize: 12, color: Couleurs.discret)),
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
}

const _encrePhoto = Color(0xFF121212);
