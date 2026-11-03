// E06 Reels, facon TikTok et Instagram : un reel par ecran, on glisse vers le
// haut pour le suivant. A droite, le createur et les reactions ; en bas, la
// legende, d ou vient la capture (badge, telephone, lieu) et « Y aller ». Un
// double toucher aime ; un appui long sur le coeur ouvre les reactions.
// En attendant la video : la couverture avance lentement, comme un plan.
import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../outils/chemins.dart';
import '../donnees/vues.dart';
import '../donnees/catalogue.dart';
import '../donnees/communaute.dart';
import '../donnees/modeles.dart';
import '../donnees/mes_publications.dart';
import '../donnees/session.dart';
import '../outils/capacites.dart';
import '../outils/langue.dart';
import '../outils/reseau.dart';
import '../outils/videos.dart';
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
import 'etats.dart';

String _court(int n) => nombreCourt(n);

/// Le son des reels, coupe ou non : le meme pour tous, comme Instagram.
final sonCoupe = ValueNotifier(false);

class EcranReels extends StatefulWidget {
  const EcranReels({super.key});

  @override
  State<EcranReels> createState() => _EcranReelsState();
}

class _EcranReelsState extends State<EcranReels> {
  // Les trois flux, cote a cote : on glisse de gauche a droite pour changer.
  final _flux = PageController(initialPage: 1);
  int _courant = 1;

  static List<String> get _noms => [t('Abonnements'), t('Découverte'), t('Près de moi')];

  // Abonnements : les createurs suivis ; Decouverte : tout ; Pres de moi : du
  // plus proche au plus loin (le lot 4 les donnera par l API). Les reels que
  // le membre vient de publier passent en tete de Decouverte et de Pres de moi.
  /// Pres de moi, tel que le serveur le donne autour de la position (sinon trie ici).
  List<Reel>? _presDeMoi;

  /// Abonnements, tel que le serveur le donne (sinon les createurs que je suis, parmi les reels recus).
  List<Reel>? _abonnements;

  @override
  void initState() {
    super.initState();
    Catalogue.instance.reelsPresDeMoi().then((r) {
      if (mounted && r != null) setState(() => _presDeMoi = r);
    });
    _chargerAbonnements();
    Communaute.instance.addListener(_suivisChangent);
  }

  int _nombreSuivis = Communaute.instance.suivis.length;

  // Je viens de suivre (ou de quitter) un createur : Abonnements se refait.
  void _suivisChangent() {
    if (Communaute.instance.suivis.length == _nombreSuivis) return;
    _nombreSuivis = Communaute.instance.suivis.length;
    _chargerAbonnements();
  }

  Future<void> _chargerAbonnements() async {
    final r = await Catalogue.instance.reelsAbonnements();
    if (mounted && r != null) setState(() => _abonnements = r);
  }

  // Mes reels en ligne viennent du serveur (compteurs, badge) : ils passent en tete, une seule fois.
  List<List<Reel>> get _fils {
    final miens = MesPublications.instance.reels;
    final dejaLa = MesPublications.instance.contenus;
    List<Reel> sansLesMiens(List<Reel> liste) => [
      for (final r in liste)
        if (r.id == null || !dejaLa.contains(r.id)) r,
    ];
    final reels = sansLesMiens(Catalogue.instance.reels);
    return [
      _abonnements ??
          [
            for (final r in reels)
              if (Communaute.instance.suivis.contains(r.pseudo)) r,
          ],
      [...miens, ...reels],
      [
        ...miens,
        ...(_presDeMoi == null ? ([...reels]..sort((a, b) => (lieuDuReel(a).distanceKm ?? 99999).compareTo(lieuDuReel(b).distanceKm ?? 99999))) : sansLesMiens(_presDeMoi!)),
      ],
    ];
  }

  // Un fil vide : pourquoi, et quoi faire.
  (String, String, String?, VoidCallback?) _vide(int f) {
    if (Catalogue.instance.horsLigne && Catalogue.instance.reels.isEmpty) {
      return ('hors-ligne', t('Aucune connexion. Les reels s’afficheront dès que le réseau sera rétabli.'), t('Réessayer'), Catalogue.instance.rafraichir);
    }
    return switch (f) {
      0 when !Communaute.instance.enLigne => ('profil', t('Connectez-vous pour vous abonner à des créateurs. Leurs reels s’afficheront ici.'), t('Se connecter'), () => context.push('/entree')),
      0 => ('reels', t('Abonnez-vous à des créateurs. Leurs reels s’afficheront ici.'), null, null),
      2 => ('lieu', t('Aucun reel près de vous pour le moment. Consultez les autres onglets.'), null, null),
      _ => ('reels', t('Aucun reel à afficher. Réessayez dans un instant.'), t('Actualiser'), Catalogue.instance.rafraichir),
    };
  }

  @override
  void dispose() {
    Communaute.instance.removeListener(_suivisChangent);
    _flux.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([MesPublications.instance, Catalogue.instance]), builder: (context, _) => _construire(context));

  Widget _construire(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: barreSombre,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView(
              controller: _flux,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _courant = i);
              },
              children: [for (var f = 0; f < 3; f++) _Fil(reels: _fils[f], actif: f == _courant, vide: _vide(f))],
            ),
            // Le haut : les trois flux et la recherche.
            Positioned(
              top: haut + 6,
              left: 16,
              right: 12,
              child: Row(
                children: [
                  // Les flux, serres a gauche comme TikTok ; la loupe a droite. Le trait
                  // suit le doigt pendant qu on glisse d un flux a l autre.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedBuilder(
                        animation: _flux,
                        builder: (context, _) {
                          final page = _flux.hasClients && _flux.position.haveDimensions ? _flux.page ?? 1.0 : _courant.toDouble();
                          return Row(
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 20),
                                GestureDetector(
                                  onTap: () => _flux.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Courbes.interface),
                                  child: Semantics(
                                    selected: _courant == i,
                                    button: true,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _noms[i],
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withValues(alpha: 0.7 + 0.3 * (1 - (page - i).abs()).clamp(0.0, 1.0)),
                                            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 8)],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 22 * (1 - (page - i).abs()).clamp(0.0, 1.0),
                                          height: 2.5,
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RondVerre(icone: 'loupe', semantique: t('Rechercher'), surPhoto: true, encre: Colors.white, onTap: () => context.push(ici(context, 'recherche'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un flux : un reel par ecran, on glisse vers le haut pour le suivant. Il
/// garde sa place quand on passe a un autre flux et qu on revient.
/// Un reel filme dans Discover, ouvert d ailleurs que des Reels (un profil, la page d un son,
/// une notification, un lien) : dans le lecteur des Reels, avec ses informations et Y aller,
/// jamais sur la page d une photo.
class EcranUnReel extends StatefulWidget {
  const EcranUnReel({super.key, required this.id});

  final String id;

  @override
  State<EcranUnReel> createState() => _EcranUnReelState();
}

class _EcranUnReelState extends State<EcranUnReel> {
  Reel? _reel;
  bool _cherche = true;

  @override
  void initState() {
    super.initState();
    // Deja connu (les Reels, les miens) : tout de suite ; puis la version du serveur, a jour.
    _reel = [...MesPublications.instance.reels, ...Catalogue.instance.reels].where((r) => r.id == widget.id).firstOrNull;
    Catalogue.instance.chargerReel(widget.id).then((r) {
      if (!mounted) return;
      setState(() {
        _cherche = false;
        if (r != null) _reel = _reel?.mien == true && _reel!.video != null && r.video == null ? _reel : r;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _reel;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: barreSombre,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (r != null)
              _Fil(reels: [r], actif: true, vide: ('reels', '', null, null))
            else if (_cherche)
              const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            else
              const EcranEtat(etat: 'introuvable'),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              left: 12,
              child: RondVerre(icone: 'retour', semantique: t('Retour'), surPhoto: true, encre: Colors.white, onTap: () => context.pop()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fil extends StatefulWidget {
  const _Fil({required this.reels, required this.actif, required this.vide});

  final List<Reel> reels;
  final bool actif;

  /// Sans reel : (icone, phrase, action, geste).
  final (String, String, String?, VoidCallback?) vide;

  @override
  State<_Fil> createState() => _FilState();
}

/// La video d un reel a lire : la 1080p en Wi-Fi, hors economie de donnees, sur un telephone qui
/// n est pas « petit » et dont l ecran a au moins 1 000 px de large ; sinon la 720p.
String? videoDuReel(BuildContext context, Reel r) {
  final hd = r.videoHd != null && !Reseau.instance.limite && !Reseau.instance.economie && !Capacites.instance.faible && View.of(context).physicalSize.shortestSide >= 1000;
  return hd ? r.videoHd : r.video;
}

class _FilState extends State<_Fil> with AutomaticKeepAliveClientMixin {
  final _pages = PageController();
  int _courant = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prechauffer(0);
    });
  }

  // Les deux reels qui suivent se gardent sur le telephone pendant celui-ci : le suivant part
  // aussitot. Pas avec « Reels au toucher » (donnees mobiles economisees).
  void _prechauffer(int i) {
    if (Reseau.instance.reelsAuToucher) return;
    for (final r in widget.reels.skip(i + 1).take(2)) {
      final v = videoDuReel(context, r);
      if (v != null) Videos.instance.prechauffer(v);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.reels.isEmpty) {
      final (icone, texte, action, geste) = widget.vide;
      return EtatVide(icone: icone, titre: t('Aucun reel'), texte: texte, action: action, onAction: geste, sombre: true);
    }
    return PageView.builder(
      controller: _pages,
      scrollDirection: Axis.vertical,
      itemCount: widget.reels.length,
      onPageChanged: (i) {
        setState(() => _courant = i);
        _prechauffer(i);
        // Trois reels avant la fin : les suivants arrivent.
        if (i >= widget.reels.length - 3) Catalogue.instance.suiteReels();
      },
      // La cle suit le reel : quand le fil s allonge ou qu un reel passe en tete, sa video le suit.
      itemBuilder: (context, i) => _Reel(key: ValueKey(widget.reels[i].id ?? widget.reels[i].video ?? widget.reels[i].photo), reel: widget.reels[i], actif: widget.actif && i == _courant),
    );
  }
}

class _Reel extends StatefulWidget {
  const _Reel({super.key, required this.reel, required this.actif});

  final Reel reel;
  final bool actif;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with TickerProviderStateMixin {
  // Le « plan » : la couverture avance lentement (transform seulement).
  late final AnimationController _plan = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  // La lecture : la barre de progression, en boucle sur la duree du reel.
  late final AnimationController _lecture = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.reel.duree),
  );
  late final AnimationController _coeur = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  // Le disque du son, en bas a droite : il tourne pendant la lecture.
  late final AnimationController _disque = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  Offset _pointCoeur = Offset.zero;

  /// Ma reaction (son emoji) : celle que le serveur connait, puis mes gestes.
  late final String? _reactionDepart = reactions[Communaute.instance.reactionSur(widget.reel.id ?? '', duServeur: widget.reel.maReaction)];
  late bool _aime = _reactionDepart != null;
  late String? _reaction = _reactionDepart;
  late bool _abonne = Communaute.instance.suit(widget.reel.pseudo);

  /// Mon reel : publie d ici, ou recu du serveur sous mon nom.
  bool get _aMoi => widget.reel.mien || (Session.instance.nomUtilisateur.isNotEmpty && widget.reel.pseudo == Session.instance.nomUtilisateur);

  int get _jaime => Communaute.instance.nombreReactions(widget.reel.id, duServeur: widget.reel.jaime, moiDuServeur: widget.reel.maReaction != null);

  // Poser (ou retirer) une reaction : tout de suite a l ecran, puis au serveur.
  Future<void> _poser(String? emoji) async {
    final avant = (_aime, _reaction);
    setState(() {
      _aime = emoji != null;
      _reaction = emoji;
    });
    final id = widget.reel.id;
    if (id == null || !Communaute.instance.enLigne) {
      setState(() {
        _aime = avant.$1;
        _reaction = avant.$2;
      });
      // Mon reel pas encore en ligne : on y reagira une fois envoye.
      id == null
          ? bulle(context, t('Ce reel est en cours d’envoi. Vous pourrez y réagir une fois qu’il sera en ligne.'), icone: 'horloge')
          : bulle(context, t('Connectez-vous pour réagir.'), icone: 'profil');
      return;
    }
    final cle = emoji == null ? null : reactions.entries.firstWhere((e) => e.value == emoji, orElse: () => reactions.entries.first).key;
    if (!await Communaute.instance.reagir(id, cle) && mounted) {
      setState(() {
        _aime = avant.$1;
        _reaction = avant.$2;
      });
      bulle(context, t('Impossible de réagir à cette publication.'), icone: 'alerte');
    }
  }

  // Les « ... » du reel : le mien se supprime ; celui d un autre s enregistre, se telecharge, se signale.
  void _options() {
    final r = widget.reel;
    final local = r.mien && r.id == null ? MesPublications.instance.liste.where((p) => p.photo == r.photo).firstOrNull : null;
    if (local != null) {
      optionsMaPublication(context, local);
      return;
    }
    optionsPublication(
      context,
      Publication(
        photo: r.photo,
        auteur: '@${r.pseudo}',
        nomAuteur: r.nom,
        avatarAuteur: r.avatar,
        appareil: r.appareil,
        dureeReel: r.duree,
        id: r.id,
        lieu: r.lieu,
        lieuNom: r.lieuNom,
        video: r.video,
        videoHd: r.videoHd,
      ),
      titre: r.lieuNom,
    );
  }

  Future<void> _suivre(bool oui) async {
    if (_aMoi) return;
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour vous abonner.'), icone: 'profil');
      return;
    }
    setState(() => _abonne = oui);
    if (await Communaute.instance.suivre(widget.reel.pseudo, oui) == null && mounted) {
      setState(() => _abonne = !oui);
      bulle(context, oui ? t('Impossible de vous abonner. Réessayez.') : t('Impossible de vous désabonner. Réessayez.'), icone: 'alerte');
    }
  }

  bool _enPause = false;
  bool _legendeOuverte = false;

  // Les animations reduites (reglage, ou telephone qui chauffe) : premier
  // appel ici, et a chaque changement.
  // L onglet Reels cache (un autre onglet, une page par-dessus) coupe les
  // tickers : la video s arrete, et son son avec, et rend son decodeur.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _jouer();
    _suivreDecodeur();
  }

  bool _visible = true;

  /// L application passee en arriere-plan : la video s arrete aussi.
  late final _cycle = AppLifecycleListener(
    onHide: () {
      _premierPlan = false;
      _jouer();
    },
    onShow: () {
      _premierPlan = true;
      _jouer();
    },
  );
  bool _premierPlan = true;

  bool get _lit => widget.actif && !_enPause && _visible && _premierPlan;

  void _sonChange() {
    _video?.setVolume(sonCoupe.value ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_Reel ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.actif && !widget.actif) _noterVue();
    if (ancien.actif != widget.actif) {
      _jouer();
      _suivreDecodeur();
    }
  }

  // Un telephone n a que quelques decodeurs video : seul le reel a l ecran (celui du fil
  // affiche, onglet Reels visible) en garde un. Les autres le rendent, et le reprennent en
  // revenant, depuis le telephone (deja garde ou precharge) : sinon les autres pages ne
  // trouvaient plus de decodeur libre et leurs videos restaient figees.
  bool get _doitLire => widget.actif && _visible && !_auToucher;
  bool _chargement = false;

  void _suivreDecodeur() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_doitLire) {
        if (_video == null && !_chargement) _chargerVideo();
      } else {
        _rendreVideo();
      }
    });
  }

  void _rendreVideo() {
    final v = _video;
    if (v == null) return;
    v.removeListener(_suivreVideo);
    _video = null;
    unawaited(v.dispose());
    if (mounted) setState(() {});
  }

  // La vraie video, pour un reel publie depuis ce telephone : elle tourne en
  // boucle quand le reel est a l ecran, et fait avancer la barre de lecture.
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _cycle;
    sonCoupe.addListener(_sonChange);
    final chemin = widget.reel.video;
    // « Lire les reels en Wi-Fi seulement », sur les données mobiles : la couverture, et la
    // vidéo se charge quand on touche le reel.
    if (chemin != null && chemin.startsWith('http') && Reseau.instance.reelsAuToucher) {
      _auToucher = true;
      return;
    }
    // Apres la premiere image : la taille de l ecran est connue.
    _suivreDecodeur();
  }

  /// Le reel attend un toucher pour charger sa vidéo (données mobiles).
  bool _auToucher = false;

  Future<void> _chargerVideo() async {
    final chemin = videoDuReel(context, widget.reel);
    final enLigne = chemin != null && chemin.startsWith('http');
    if (chemin != null && (enLigne || File(chemin).existsSync())) {
      // Un reel publie d ici : son fichier ; un reel du serveur : depuis le telephone s il y est
      // deja (vu, ou precharge pendant le reel d avant), sinon en continu.
      _chargement = true;
      final v = await Videos.instance.lecteur(chemin);
      _chargement = false;
      // Plus a l ecran entre-temps : pas de decodeur pris pour rien.
      if (!mounted || !_doitLire) {
        unawaited(v.dispose());
        return;
      }
      _video = v;
      v.addListener(_suivreVideo);
      try {
        await v.initialize();
      } catch (_) {
        // Le reseau a lache : la couverture reste, la video retente une fois.
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted || _video != v) return;
        v.removeListener(_suivreVideo);
        _video = null;
        unawaited(v.dispose());
        if (_essaiVideo++ < 2) unawaited(_chargerVideo());
        return;
      }
      if (!mounted) return;
      await v.setLooping(true);
      await v.setVolume(sonCoupe.value ? 0 : 1);
      setState(() {});
      _jouer();
    }
  }

  int _essaiVideo = 0;

  void _ouvrirSon() {
    final id = widget.reel.musiqueId;
    if (id != null) context.push(ici(context, 'son/$id'));
  }

  void _suivreVideo() {
    final v = _video;
    if (v == null || !v.value.isInitialized || v.value.duration == Duration.zero) return;
    final avance = v.value.position.inMilliseconds / v.value.duration.inMilliseconds;
    // La video repart au debut (elle boucle) ou touche la fin : vue jusqu au bout.
    if (avance >= 0.97 || (_lecture.value > 0.85 && avance < 0.15)) _jusquAuBout = true;
    _lecture.value = avance;
  }

  // Le temps de lecture de ce reel (la video a l ecran et qui joue), et s il a ete vu en entier.
  final _regard = Stopwatch();
  bool _jusquAuBout = false;

  // Le reel quitte l ecran : sa vue part (le serveur decide si elle compte : 3 s au moins).
  void _noterVue() {
    _regard.stop();
    final id = widget.reel.id;
    if (id != null && !_aMoi && _regard.elapsed > Duration.zero) {
      Vues.instance.noter(id, _regard.elapsed, complete: _jusquAuBout);
    }
    _regard.reset();
    _jusquAuBout = false;
  }

  void _jouer() {
    final v = _video;
    if (v != null) {
      // Une vraie video : elle joue ou s arrete, sans le « plan » de la couverture.
      _plan.stop();
      _lecture.stop();
      if (_lit) {
        if (v.value.isInitialized) {
          v.play();
          _regard.start();
        }
        if (mouvementsContinus(context)) _disque.repeat();
      } else {
        v.pause();
        _regard.stop();
        _disque.stop();
      }
      return;
    }
    // Pas de video qui joue : la couverture seule. La barre reste a zero et le
    // disque immobile ; seul le plan avance doucement (sauf en mode leger).
    _lecture.stop();
    _disque.stop();
    if (_lit && mouvementsContinus(context)) {
      _plan.repeat(reverse: true);
    } else {
      _plan.stop();
    }
  }

  @override
  void dispose() {
    _noterVue();
    _cycle.dispose();
    sonCoupe.removeListener(_sonChange);
    _video?.removeListener(_suivreVideo);
    _video?.dispose();
    _plan.dispose();
    _lecture.dispose();
    _coeur.dispose();
    _disque.dispose();
    super.dispose();
  }

  void _doubleToucher(TapDownDetails d) => _pointCoeur = d.localPosition;

  void _aimerAuDoubleToucher() {
    if (!_aime) _poser(_reaction ?? '❤️');
    HapticFeedback.lightImpact();
    _coeur.forward(from: 0);
  }

  final _cleCoeur = GlobalKey();

  Offset _centreDuCoeur() {
    final boite = _cleCoeur.currentContext?.findRenderObject() as RenderBox?;
    if (boite == null) return MediaQuery.sizeOf(context).center(Offset.zero);
    return boite.localToGlobal(boite.size.center(Offset.zero));
  }

  Future<void> _choisirReaction(Offset ou) async {
    HapticFeedback.mediumImpact();
    final choix = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: t('Fermer'),
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, _, _) => _ChoixReaction(ou: ou),
      transitionBuilder: (context, a, _, enfant) => ScaleTransition(
        alignment: Alignment(((ou.dx / MediaQuery.sizeOf(context).width) * 2 - 1), ((ou.dy / MediaQuery.sizeOf(context).height) * 2 - 1)),
        scale: CurvedAnimation(parent: a, curve: Courbes.ressort, reverseCurve: Curves.easeIn),
        child: FadeTransition(opacity: a, child: enfant),
      ),
    );
    if (choix != null) _poser(choix);
  }

  Future<void> _yAller(Lieu lieu) => yAller(context, lieu);

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    final aMoi = _aMoi;
    final lieu = lieuDuReel(r);
    // Le corps passe sous la barre d onglets : sa hauteur est deja dans le padding.
    final bas = MediaQuery.paddingOf(context).bottom + 16;
    return Stack(
      fit: StackFit.expand,
      children: [
        // La video (ici sa couverture), un toucher met en pause, deux aiment.
        GestureDetector(
          onTap: () {
            if (_auToucher) {
              setState(() => _auToucher = false);
              _chargerVideo();
              return;
            }
            setState(() => _enPause = !_enPause);
            _jouer();
          },
          onDoubleTapDown: _doubleToucher,
          onDoubleTap: _aimerAuDoubleToucher,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _plan,
              builder: (context, enfant) => Transform.scale(scale: 1.04 + 0.06 * Curves.easeInOut.transform(_plan.value), alignment: const Alignment(0.2, -0.1), child: enfant),
              child: _video != null && _video!.value.isInitialized
                  // La video remplit l ecran, comme la couverture.
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(width: _video!.value.size.width, height: _video!.value.size.height, child: VideoPlayer(_video!)),
                    )
                  : Photo(r.photo),
            ),
          ),
        ),
        // Des voiles en haut et en bas, pour lire le blanc sur n importe quelle image.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80060A14), Color(0x00060A14), Color(0x00060A14), Color(0x73060A14), Color(0xE0060A14)],
                stops: [0, 0.2, 0.42, 0.66, 1],
              ),
            ),
          ),
        ),
        if (_enPause || _auToucher)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Icone('lecture', taille: 34, couleur: Colors.white),
              ),
            ),
          ),
        // Le coeur du double toucher : il jaillit, puis monte et s efface.
        AnimatedBuilder(
          animation: _coeur,
          builder: (context, _) {
            final t = _coeur.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();
            final echelle = Courbes.ressort.transform((t / 0.35).clamp(0.0, 1.0)) * (1 + 0.2 * t);
            return Positioned(
              left: _pointCoeur.dx - 48,
              top: _pointCoeur.dy - 48 - 60 * Curves.easeIn.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0)),
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1 - ((t - 0.6) / 0.4).clamp(0.0, 1.0)),
                  child: Transform.scale(
                    scale: echelle,
                    child: Icone('coeur-plein', taille: 96, couleur: Couleurs.erreur),
                  ),
                ),
              ),
            );
          },
        ),
        // A droite : le createur et les reactions.
        Positioned(
          right: 10,
          bottom: bas + 6,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => aMoi ? context.go('/profil') : context.push(ici(context, 'createur/${r.pseudo}')),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      padding: const EdgeInsets.all(2),
                      child: Avatar(nom: r.nom, taille: 46, photo: r.avatar),
                    ),
                    if (!_abonne && !aMoi)
                      Positioned(
                        bottom: -9,
                        child: GestureDetector(
                          onTap: () => _suivre(true),
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Couleurs.ocean, shape: BoxShape.circle),
                            child: const Icone('plus', taille: 14, couleur: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Le nombre exact arrive du serveur apres mon geste : il suit, sans recharger.
              ListenableBuilder(
                listenable: Communaute.instance,
                builder: (context, _) => _BoutonReel(
                  icone: _aime ? 'coeur-plein' : 'coeur',
                  couleur: _aime ? Couleurs.erreur : null,
                  emoji: _aime && _reaction != null && _reaction != '❤️' ? _reaction : null,
                  compte: _court(_jaime),
                  semantique: _aime ? t('Je n’aime plus') : t('J’aime'),
                  // Pas encore de reaction : le toucher ouvre le choix, pose la ou
                  // est le coeur. Deja une reaction : le toucher la retire.
                  onTap: () => _aime ? _poser(null) : _choisirReaction(_centreDuCoeur()),
                  onLongPress: _choisirReaction,
                  cle: _cleCoeur,
                  onCompte: () => feuilleReactions(context, total: _court(_jaime), contenu: r.id),
                ),
              ),
              // Le nombre suit chaque commentaire ajoute ou retire, sans recharger.
              ListenableBuilder(
                listenable: Communaute.instance,
                builder: (context, _) => _BoutonReel(
                  icone: 'commentaire',
                  compte: _court(Communaute.instance.nombreCommentaires(r.id, r.commentaires)),
                  semantique: t('Commentaires'),
                  onTap: () => feuilleCommentaires(context, nombre: r.commentaires, auteur: r.nom, contenu: r.id, monContenu: aMoi),
                ),
              ),
              // Enregistrer et Partager sont dans les « ... » : la colonne reste legere.
              _BoutonReel(icone: 'plus-points', compte: '', semantique: t('Plus d’options'), onTap: _options),
              _BoutonReel(
                icone: sonCoupe.value ? 'muet' : 'son',
                compte: '',
                semantique: sonCoupe.value ? t('Remettre le son') : t('Couper le son'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  sonCoupe.value = !sonCoupe.value;
                },
              ),
              // Le disque d une musique posee sur le reel : il tourne pendant la lecture, comme TikTok.
              // Sans musique (le son d origine), pas de disque.
              if (r.aUneMusique)
                // Le toucher ouvre la page du son : les reels qui l utilisent, « Utiliser ce son ».
                Semantics(
                  button: r.musiqueId != null,
                  label: t('Son : {son}', {'son': r.sonLisible}),
                  child: GestureDetector(
                    onTap: _ouvrirSon,
                    child: RotationTransition(
                      turns: _disque,
                      child: Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A1C22)),
                        child: ClipOval(child: Photo(r.photo)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Le depliant ouvert : la video s assombrit un peu ; la toucher replie.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_legendeOuverte,
            child: GestureDetector(
              onTap: () => setState(() => _legendeOuverte = false),
              child: AnimatedOpacity(
                opacity: _legendeOuverte ? 1 : 0,
                duration: Durees.interface,
                child: const ColoredBox(color: Color(0x59000000)),
              ),
            ),
          ),
        ),
        // En bas : qui, quoi, et Y aller ; le reste dans le depliant.
        Positioned(
          left: 16,
          right: 84,
          bottom: bas,
          child: DefaultTextStyle(
            style: TextStyle(fontFamily: famillePolice, color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => aMoi ? context.go('/profil') : context.push(ici(context, 'createur/${r.pseudo}')),
                      child: Text(r.pseudo, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                    if (!aMoi) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _suivre(!_abonne),
                        child: AnimatedContainer(
                          duration: Durees.interface,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _abonne ? Couleurs.limonade : Couleurs.ocean, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_abonne) ...[Icone('coche', taille: 14, couleur: Couleurs.encreLimonade), const SizedBox(width: 4)],
                              Text(
                                _abonne ? t('Abonné') : t('S’abonner'),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _abonne ? Couleurs.encreLimonade : Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Comme TikTok : la legende sur deux lignes, puis « plus ». Un
                // toucher deplie tout (la legende, le badge, le telephone, le
                // lieu) ; un autre replie. La vue reste degagee.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _legendeOuverte = !_legendeOuverte),
                  child: AnimatedSize(
                    duration: Durees.interface,
                    curve: Courbes.interface,
                    alignment: Alignment.bottomLeft,
                    child: _legendeOuverte
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.legende, style: _styleLegende),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  BadgeCapture(verifie: r.verifiee, court: true),
                                  _Info(icone: 'telephone', texte: r.appareil),
                                  // Toujours la, meme a 0, et a jour ; l auteur seul voit qui a vu.
                                  if (r.id != null)
                                    ListenableBuilder(
                                      listenable: Vues.instance,
                                      builder: (context, _) {
                                        final n = Vues.instance.nombre(r.id, r.vues);
                                        final info = _Info(icone: 'oeil', texte: vuesLisibles(n));
                                        if (!_aMoi) return info;
                                        return Appuyable(
                                          semantique: t('{vues}, voir qui a vu', {'vues': vuesLisibles(n)}),
                                          onTap: () => feuilleSpectateurs(context, contenu: r.id!, total: n),
                                          child: info,
                                        );
                                      },
                                    ),
                                  // Sans lieu : le nom donne en publiant, s il y en a un.
                                  _Info(icone: 'lieu', texte: lieu.situe ? lieu.nom : r.lieuNom ?? lieu.nom),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Y aller : petit, seulement dans le depliant ouvert, et pour un lieu situe.
                              if (lieu.situe) ...[_YAller(onTap: () => _yAller(lieu)), const SizedBox(height: 8)],
                              Text('moins', style: _styleLegende.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          )
                        // Sans legende, le lieu et « plus » : le depliant (et Y aller) reste a portee.
                        : r.legende.trim().isEmpty
                        ? Text.rich(
                            TextSpan(
                              style: _styleLegende,
                              children: [
                                TextSpan(text: '${lieu.situe ? lieu.nom : r.lieuNom ?? lieu.nom} · '),
                                TextSpan(
                                  text: t('plus'),
                                  style: _styleLegende.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : _LegendeCourte(r.legende),
                  ),
                ),
                if (r.aUneMusique) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _ouvrirSon,
                    child: Row(
                      children: [
                        const Icone('musique', taille: 15, couleur: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            // Un son du catalogue : son titre et son artiste ; sinon, avec le createur.
                            r.musiqueId != null ? r.son : '${r.sonLisible} · ${r.pseudo}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // La progression de la lecture, juste au-dessus de la barre d onglets.
        Positioned(
          left: 16,
          right: 16,
          bottom: bas - 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 2.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.white.withValues(alpha: 0.25)),
                  AnimatedBuilder(
                    animation: _lecture,
                    builder: (context, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _lecture.value,
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoutonReel extends StatelessWidget {
  const _BoutonReel({required this.icone, required this.compte, required this.semantique, required this.onTap, this.couleur, this.emoji, this.onLongPress, this.onCompte, this.cle});

  final Key? cle;
  final String icone;
  final String compte;
  final String semantique;
  final VoidCallback onTap;
  final Color? couleur;
  final String? emoji;
  final ValueChanged<Offset>? onLongPress;
  final VoidCallback? onCompte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Builder(
          builder: (context) => GestureDetector(
            onLongPressStart: onLongPress == null ? null : (d) => onLongPress!(d.globalPosition),
            child: Appuyable(
              key: cle,
              semantique: semantique,
              onTap: onTap,
              verre: true,
              rayonVerre: 24,
              child: Verre(
                rayon: 24,
                surFond: false,
                ombre: false,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: emoji != null ? Text(emoji!, style: const TextStyle(fontSize: 24)) : Icone(icone, taille: 26, couleur: couleur ?? Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onCompte,
          child: Text(
            compte,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Y aller, en petit : une pastille bleue, l icone et le mot.
class _YAller extends StatelessWidget {
  const _YAller({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Appuyable(
    semantique: t('Y aller'),
    verre: true,
    rayonVerre: 16,
    gonflement: 0.08,
    onTap: onTap,
    child: Verre(
      teinte: TeinteVerre.ocean,
      rayon: 16,
      child: SizedBox(
        height: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icone('y-aller', taille: 16, couleur: Colors.white),
              const SizedBox(width: 6),
              Text(
                t('Y aller'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const _styleLegende = TextStyle(fontSize: 14.5, height: 1.4, color: Colors.white);

/// La legende repliee : deux lignes au plus, et « … plus » a la fin de la
/// seconde quand elle est coupee (comme TikTok).
class _LegendeCourte extends StatelessWidget {
  const _LegendeCourte(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, contraintes) {
      final style = DefaultTextStyle.of(context).style.merge(_styleLegende);
      final plus = TextSpan(
        text: t('plus'),
        style: style.copyWith(fontWeight: FontWeight.w700),
      );
      final echelle = MediaQuery.textScalerOf(context);
      bool tient(String debut, {bool suite = true}) {
        final peintre = TextPainter(
          text: TextSpan(
            style: style,
            children: [
              TextSpan(text: debut),
              if (suite) ...[const TextSpan(text: '… '), plus],
            ],
          ),
          maxLines: 2,
          textDirection: TextDirection.ltr,
          textScaler: echelle,
        )..layout(maxWidth: contraintes.maxWidth);
        final ok = !peintre.didExceedMaxLines;
        peintre.dispose();
        return ok;
      }

      if (tient(texte, suite: false)) return Text(texte, style: style);
      // Le plus long debut qui tient avec « … plus ».
      var bas = 0, haut = texte.length;
      while (bas < haut) {
        final m = (bas + haut + 1) ~/ 2;
        if (tient(texte.substring(0, m))) {
          bas = m;
        } else {
          haut = m - 1;
        }
      }
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: texte.substring(0, bas).trimRight()),
            const TextSpan(text: '… '),
            plus,
          ],
        ),
      );
    },
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.icone, required this.texte});

  final String icone;
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    padding: const EdgeInsets.fromLTRB(7, 0, 9, 0),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.38), borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icone(icone, taille: 14),
        const SizedBox(width: 4),
        Text(
          texte,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    ),
  );
}

// Le nom de chaque reaction, sous son emoji (reactionsUsw, dans le meme ordre).
List<String> get _nomsReactions => [t('J’aime'), t('Waou'), t('Envie d’y aller'), t('Merci')];

/// Le choix d une reaction : une pastille de verre qui s ouvre la ou on a appuye.
class _ChoixReaction extends StatelessWidget {
  const _ChoixReaction({required this.ou});

  final Offset ou;

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    const l = 4 * 74.0 + 16;
    return Stack(
      children: [
        Positioned(
          left: (ou.dx - l - 34).clamp(12.0, largeur - l - 12),
          top: ou.dy - 46,
          child: Material(
            type: MaterialType.transparency,
            child: Verre(
              rayon: 32,
              surFond: false,
              ombre: false,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(32)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, e) in reactionsUsw.indexed)
                        Appuyable(
                          semantique: _nomsReactions[i],
                          verre: true,
                          gonflement: 0.3,
                          onTap: () => Navigator.of(context).pop(e),
                          child: SizedBox(
                            width: 74,
                            height: 76,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(e, style: const TextStyle(fontSize: 30)),
                                const SizedBox(height: 2),
                                Text(
                                  _nomsReactions[i],
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: TextStyle(fontSize: 11, height: 1.1, fontWeight: FontWeight.w600, color: Couleurs.hsl(0, 0, 7)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
