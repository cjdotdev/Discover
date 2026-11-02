// E06 Reels (repris de usw_mobile), façon TikTok et Instagram : un reel par écran,
// on glisse vers le haut pour le suivant. À droite, le créateur et les actions ;
// en bas, la légende et d'où vient la capture (badge, téléphone, lieu). Un double
// toucher aime. Sans vidéo de démonstration : la couverture avance lentement.
// Hors du MVP (repartition.md) : le choix des réactions et leurs feuilles ; on garde
// le j'aime et les commentaires renvoient à E07.
// À brancher : GET reels.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/donnees/demo.dart';
import '../../decouverte/widgets/avatar.dart';
import '../../decouverte/widgets/jetons.dart';
import '../../decouverte/widgets/photo.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/demo.dart';

String _court(int n) => nombreCourt(n);

/// E06 Reels. Voir repartition.md.
class EcranReels extends StatefulWidget {
  const EcranReels({super.key});

  @override
  State<EcranReels> createState() => _EcranReelsState();
}

class _EcranReelsState extends State<EcranReels> {
  final _pages = PageController();
  int _courant = 0;
  int _flux = 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final style = DefaultTextStyle.of(context).style;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              scrollDirection: Axis.vertical,
              itemCount: reelsDemo.length,
              onPageChanged: (i) => setState(() => _courant = i),
              itemBuilder: (context, i) => _Reel(reel: reelsDemo[i], actif: i == _courant),
            ),
            // Le haut : les trois flux et la recherche.
            Positioned(
              top: haut + 6,
              left: 16,
              right: 12,
              child: Row(
                children: [
                  // Les flux, serrés à gauche comme TikTok ; la loupe à droite.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          for (final (i, nom) in [(0, 'Abonnements'), (1, 'Découverte'), (2, 'Près de moi')]) ...[
                            if (i > 0) const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => setState(() => _flux = i),
                              child: Semantics(
                                selected: _flux == i,
                                button: true,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      nom,
                                      style: style.copyWith(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: _flux == i ? 1 : 0.7),
                                        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 8)],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Le ressort dépasse sa cible : le trait ne doit pas passer sous zéro.
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(end: _flux == i ? 22 : 0),
                                      duration: const Duration(milliseconds: 420),
                                      curve: CourbesPlus.ressort,
                                      builder: (context, largeur, _) => Container(
                                        width: largeur.clamp(0, double.infinity),
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RondVerre(
                    icone: 'loupe',
                    semantique: 'Rechercher',
                    surPhoto: true,
                    encre: Colors.white,
                    onTap: () => context.push(Routes.recherche),
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

class _Reel extends StatefulWidget {
  const _Reel({required this.reel, required this.actif});

  final Reel reel;
  final bool actif;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with TickerProviderStateMixin {
  // Le « plan » : la couverture avance lentement (transform seulement).
  late final AnimationController _plan = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  // La lecture : la barre de progression, en boucle sur la durée du reel.
  late final AnimationController _lecture = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.reel.duree),
  );
  late final AnimationController _coeur = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  // Le disque du son, en bas à droite : il tourne pendant la lecture.
  late final AnimationController _disque = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  Offset _pointCoeur = Offset.zero;
  bool _aime = false;
  bool _abonne = false;
  bool _enPause = false;
  bool _legendeOuverte = false;

  @override
  void initState() {
    super.initState();
    _jouer();
  }

  @override
  void didUpdateWidget(_Reel ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.actif != widget.actif) _jouer();
  }

  void _jouer() {
    if (widget.actif && !_enPause) {
      _plan.repeat(reverse: true);
      _lecture.repeat();
      _disque.repeat();
    } else {
      _plan.stop();
      _lecture.stop();
      _disque.stop();
    }
  }

  @override
  void dispose() {
    _plan.dispose();
    _lecture.dispose();
    _coeur.dispose();
    _disque.dispose();
    super.dispose();
  }

  void _doubleToucher(TapDownDetails d) => _pointCoeur = d.localPosition;

  void _aimerAuDoubleToucher() {
    setState(() => _aime = true);
    HapticFeedback.lightImpact();
    _coeur.forward(from: 0);
  }

  // « Y aller » ouvrait l'itinéraire dans Maps avec le paquet url_launcher, absent
  // de pubspec.yaml (le socle). Mis de côté pour le moment :
  //
  // Future<void> _yAller(Lieu lieu) async {
  //   final itineraire = Uri.parse(
  //     'https://www.google.com/maps/dir/?api=1&destination=${lieu.latitude},${lieu.longitude}',
  //   );
  //   final ouvert = await launchUrl(itineraire, mode: LaunchMode.externalApplication);
  //   if (!ouvert && mounted) bulle(context, "Maps n'a pas pu s'ouvrir.");
  // }

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    final lieu = lieuDe(r.lieu);
    // Le corps passe sous la barre d'onglets : sa hauteur est déjà dans le padding.
    final bas = MediaQuery.paddingOf(context).bottom + 16;
    return Stack(
      fit: StackFit.expand,
      children: [
        // La vidéo (ici sa couverture), un toucher met en pause, deux aiment.
        GestureDetector(
          onTap: () {
            setState(() => _enPause = !_enPause);
            _jouer();
          },
          onDoubleTapDown: _doubleToucher,
          onDoubleTap: _aimerAuDoubleToucher,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _plan,
              builder: (context, enfant) => Transform.scale(
                scale: 1.04 + 0.06 * Curves.easeInOut.transform(_plan.value),
                alignment: const Alignment(0.2, -0.1),
                child: enfant,
              ),
              child: Photo(r.photo),
            ),
          ),
        ),
        // Des voiles en haut et en bas, pour lire le blanc sur n'importe quelle image.
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
        if (_enPause)
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
        // Le cœur du double toucher : il jaillit, puis monte et s'efface.
        AnimatedBuilder(
          animation: _coeur,
          builder: (context, _) {
            final t = _coeur.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();
            final echelle = CourbesPlus.ressort.transform((t / 0.35).clamp(0.0, 1.0)) * (1 + 0.2 * t);
            return Positioned(
              left: _pointCoeur.dx - 48,
              top: _pointCoeur.dy - 48 - 60 * Curves.easeIn.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0)),
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1 - ((t - 0.6) / 0.4).clamp(0.0, 1.0)),
                  child: Transform.scale(
                    scale: echelle,
                    child: const Icone('coeur-plein', taille: 96, couleur: Couleurs.erreur),
                  ),
                ),
              ),
            );
          },
        ),
        // À droite : le créateur et les actions.
        Positioned(
          right: 10,
          bottom: bas + 6,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => context.push(Routes.createur(r.pseudo)),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      padding: const EdgeInsets.all(2),
                      child: Avatar(nom: r.nom, taille: 46),
                    ),
                    if (!_abonne)
                      Positioned(
                        bottom: -9,
                        child: GestureDetector(
                          onTap: () => setState(() => _abonne = true),
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Couleurs.ocean, shape: BoxShape.circle),
                            child: const Icone('plus', taille: 14, couleur: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _BoutonReel(
                icone: _aime ? 'coeur-plein' : 'coeur',
                couleur: _aime ? Couleurs.erreur : null,
                compte: _court(r.jaime + (_aime ? 1 : 0)),
                semantique: _aime ? "Je n'aime plus" : "J'aime",
                onTap: () => setState(() => _aime = !_aime),
              ),
              _BoutonReel(
                icone: 'commentaire',
                compte: _court(r.commentaires),
                semantique: 'Commentaires',
                onTap: () => context.push(Routes.commentaires(idCommentairesReel(r))),
              ),
              // Enregistrer (E09) et partager (E10) sont hors du MVP : un simple message.
              _BoutonReel(
                icone: 'enregistrer',
                compte: _court(r.enregistres),
                semantique: 'Enregistrer',
                onTap: () => bulle(context, 'Reel enregistré dans vos collections.'),
              ),
              _BoutonReel(
                icone: 'partager',
                compte: _court(r.partages),
                semantique: 'Partager',
                onTap: () => bulle(context, 'Le lien du reel est copié.'),
              ),
              // Le disque du son : il tourne pendant la lecture, comme TikTok.
              Semantics(
                label: 'Son : ${r.son}',
                child: RotationTransition(
                  turns: _disque,
                  child: Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0xFF3A3D48), Color(0xFF111318)]),
                    ),
                    child: ClipOval(child: Photo(r.photo)),
                  ),
                ),
              ),
            ],
          ),
        ),
        // En bas : qui, quoi, d'où.
        Positioned(
          left: 16,
          right: 84,
          bottom: bas,
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => context.push(Routes.createur(r.pseudo)),
                        child: Text(
                          r.pseudo,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _abonne = !_abonne),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _abonne ? 'Abonné' : "S'abonner",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _legendeOuverte = !_legendeOuverte),
                  child: AnimatedSize(
                    duration: Durees.interface,
                    curve: Courbes.interface,
                    alignment: Alignment.topLeft,
                    child: Text(
                      r.legende,
                      maxLines: _legendeOuverte ? 8 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const BadgeCapture(verifie: true, court: true),
                    _Info(icone: 'telephone', texte: r.appareil),
                    _Info(icone: 'lieu', texte: lieu.nom),
                  ],
                ),
                // Le bouton « Y aller », mis de côté avec _yAller ci-dessus :
                // const SizedBox(height: 12),
                // BoutonVerre(
                //   texte: lieu.distanceKm != null ? 'Y aller · ${lieu.distanceKm} km' : 'Y aller',
                //   plein: true,
                //   large: false,
                //   widgetIcone: const Icone('y-aller', taille: 20),
                //   onTap: () => _yAller(lieu),
                // ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icone('musique', taille: 15, couleur: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${r.son} · ${r.pseudo}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // La progression de la lecture, juste au-dessus de la barre d'onglets.
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
  const _BoutonReel({
    required this.icone,
    required this.compte,
    required this.semantique,
    required this.onTap,
    this.couleur,
  });

  final String icone;
  final String compte;
  final String semantique;
  final VoidCallback onTap;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Appuyable(
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
              child: Center(child: Icone(icone, taille: 26, couleur: couleur ?? Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          compte,
          style: DefaultTextStyle.of(context).style.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
          ),
        ),
      ],
    ),
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
        Icone(icone, taille: 14, couleur: Colors.white),
        const SizedBox(width: 4),
        Text(
          texte,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    ),
  );
}
