// Le verre liquide de USW, a plat : une masse unie et un filet fin sur le
// bord, sans ombre portee ni degrade haut-bas (qui le bombaient). Le liquide
// est dans le geste : au toucher il gonfle, la lumiere suit le doigt, et il
// revient comme une goutte de gel (Appuyable). Pas de flou : il couterait cher
// au telephone.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import 'icone.dart';
import 'lentille.dart';

/// clair : le verre ; ocean : l action principale ; retenu : choisi ;
/// rouge : ce qui retire ou signale ; limonade : ce qui valide (moderation) ;
/// vert : ce qui est fait (abonne).
enum TeinteVerre { clair, ocean, retenu, rouge, limonade, vert }

class Verre extends StatelessWidget {
  const Verre({super.key, required this.child, this.rayon = Mesures.rayonBouton, this.teinte = TeinteVerre.clair, this.padding, this.ombre = true, this.surFond = true, this.lentille = true});

  final Widget child;
  final double rayon;
  final TeinteVerre teinte;
  final EdgeInsetsGeometry? padding;
  final bool ombre;

  /// Pose sur le fond uni de la page. Flutter peint l ombre portee sous toute
  /// la surface (la CSS, seulement autour) : a travers une masse transparente
  /// on la verrait, en tache grise. On glisse donc le fond de la page dessous.
  /// Faux sur une photo ou une video : la masse doit rester transparente.
  final bool surFond;

  /// Faux quand une lentille l entoure deja (les feuilles) : pas de double courbure.
  final bool lentille;

  @override
  Widget build(BuildContext context) {
    final nuit = Couleurs.sombre;
    // L appui du doigt (Appuyable) : de 0 au repos a 1 enfonce, un peu au-dela
    // ou en deca pendant le rebond. Le verre s y creuse comme de l eau.
    final v = AppuiVerre.de(context).clamp(-0.3, 1.2);
    final colore = teinte == TeinteVerre.ocean || teinte == TeinteVerre.rouge || teinte == TeinteVerre.limonade || teinte == TeinteVerre.vert;
    final masse = switch (teinte) {
      TeinteVerre.ocean => Couleurs.ocean.withValues(alpha: 0.9),
      TeinteVerre.rouge => Couleurs.erreur.withValues(alpha: 0.9),
      TeinteVerre.limonade || TeinteVerre.vert => Couleurs.limonade.withValues(alpha: 0.92),
      TeinteVerre.retenu => Couleurs.ocean.withValues(alpha: 0.1),
      // Sur la page : un blanc laiteux ; sur une photo : presque transparent.
      TeinteVerre.clair => surFond ? Colors.white.withValues(alpha: nuit ? 0.08 : 0.5) : Colors.white.withValues(alpha: 0.14),
    };
    final verre = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rayon),
        color: masse,
        border: teinte == TeinteVerre.retenu ? Border.all(color: Couleurs.ocean, width: 1.4) : null,
      ),
      child: CustomPaint(
        foregroundPainter: teinte == TeinteVerre.retenu ? null : RefletVerre(rayon: rayon, nuit: nuit, eclat: v.clamp(0.0, 1.0), couleur: colore),
        // Un verre sans lentille porte celle qui l entoure (une feuille, une alerte) :
        // ce qui est pose dessus n en ajoute pas (SansLentille).
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: lentille ? child : SansLentille(child: child),
        ),
      ),
    );
    if (!lentille) return verre;
    return Lentille(
      rayon: rayon,
      partage: true,
      // Le bord courbe l image dessous ; enfonce, il la courbe davantage, le
      // centre grossit un peu et le bord s irise.
      biseau: (rayon * 0.9).clamp(6.0, 16.0),
      force: 2.5 + 5 * v,
      depoli: surFond ? 0.6 : 0.3,
      dispersion: 0.5 + 1.8 * v.clamp(0.0, 1.0),
      zoom: 1 + 0.04 * v,
      child: verre,
    );
  }
}

/// L appui en cours, transmis par Appuyable au verre qu il contient.
class AppuiVerre extends InheritedNotifier<Animation<double>> {
  const AppuiVerre({super.key, required Animation<double> appui, required super.child}) : super(notifier: appui);

  /// 0 hors de tout appui.
  static double de(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppuiVerre>()?.notifier?.value ?? 0;
}

/// L appui. Une carte ou une photo se tasse un peu. Un objet de verre
/// (`verre`), comme sur iOS 26 : il gonfle sous le doigt, une lumiere s allume
/// la ou on touche, puis au relache il revient comme une goutte de gel, avec
/// un rebond (un vrai ressort : il garde l elan du geste).
class Appuyable extends StatefulWidget {
  const Appuyable({super.key, required this.child, this.onTap, this.onLongPress, this.semantique, this.actif = true, this.verre = false, this.rayonVerre, this.gonflement = 0.12});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semantique;
  final bool actif;

  /// Un objet de verre : il gonfle et s eclaire au lieu de se tasser.
  final bool verre;

  /// La forme de la lumiere (le rayon du verre). Nul : pas de lumiere.
  final double? rayonVerre;

  /// De combien il gonfle (0,12 : un bouton rond ; moins pour un large bouton).
  final double gonflement;

  @override
  State<Appuyable> createState() => _AppuyableState();
}

class _AppuyableState extends State<Appuyable> with SingleTickerProviderStateMixin {
  // 0 au repos, 1 appuye ; le ressort du relache le fait passer un peu sous 0.
  late final AnimationController _c = AnimationController.unbounded(vsync: this);
  Offset? _point;
  bool _appuye = false;

  static final _ressortAppui = SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.85);
  static final _ressortRelache = SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.42);

  // Une grande surface (une carte, un large bouton) revient sans trembler : un seul
  // petit rebond. Le rebond franc reste aux petits objets (ronds, pastilles).
  static final _ressortRelacheLarge = SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.72);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _appuyer(Offset point) {
    if (!widget.actif) return;
    _appuye = true;
    setState(() => _point = point);
    _c.animateWith(SpringSimulation(_ressortAppui, _c.value, 1, _c.velocity));
  }

  Future<void> _relacher() async {
    if (!_appuye) return;
    _appuye = false;
    // Un toucher bref : le geste va jusqu au bout avant de revenir.
    if (_c.value < 0.7) await _c.animateTo(1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut);
    if (!mounted || _appuye) return;
    _c.animateWith(SpringSimulation(widget.gonflement < 0.08 ? _ressortRelacheLarge : _ressortRelache, _c.value, 0, _c.velocity));
  }

  @override
  Widget build(BuildContext context) {
    final actif = widget.actif && (widget.onTap != null || widget.onLongPress != null);
    final reduit = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      enabled: actif,
      label: widget.semantique,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: actif && !reduit ? (d) => _appuyer(d.localPosition) : null,
        onTapUp: actif ? (_) => _relacher() : null,
        onTapCancel: _relacher,
        onTap: actif ? widget.onTap : null,
        onLongPress: actif ? widget.onLongPress : null,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final v = _c.value;
            final echelle = widget.verre ? 1 + widget.gonflement * v : 1 - 0.035 * v;
            final rayon = widget.rayonVerre;
            // La meme structure du debut a la fin de l appui : changer de parent
            // detruisait le verre et sa lentille, et le bouton clignotait.
            if (!widget.verre || rayon == null) return Transform.scale(scale: echelle, child: child);
            return Transform.scale(
              scale: echelle,
              // passthrough : le contenu garde la taille que lui donne son parent (une case de grille).
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  child!,
                  // La lumiere du toucher, dans la forme du verre ; eteinte au repos.
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: _Lumiere(_point ?? Offset.zero, rayon, _point == null ? 0 : v.clamp(0.0, 1.0) * 0.32))),
                  ),
                ],
              ),
            );
          },
          // Le verre dedans suit l appui : sa lentille se creuse, son bord s eclaire.
          child: widget.verre ? AppuiVerre(appui: _c, child: widget.child) : widget.child,
        ),
      ),
    );
  }
}

class _Lumiere extends CustomPainter {
  _Lumiere(this.point, this.rayon, this.force);

  final Offset point;
  final double rayon;
  final double force;

  @override
  void paint(Canvas canvas, Size size) {
    if (force <= 0.003) return;
    final forme = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(rayon));
    canvas.clipRRect(forme);
    final portee = size.longestSide * 0.9;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: force),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: point, radius: portee)),
    );
  }

  @override
  bool shouldRepaint(_Lumiere ancien) => ancien.point != point || ancien.force != force || ancien.rayon != rayon;
}

/// Le bouton : un rectangle arrondi, pas une pilule, fait de verre liquide.
///
/// Une action qui prend du temps (son onTap rend un Future : envoyer le code, publier,
/// supprimer...) fait tourner le logo de Discover a la place du texte jusqu a ce qu elle
/// finisse ; le bouton ne repond plus entre-temps. Rien ne tourne si elle finit tout de
/// suite, ni pendant qu une page ou une feuille qu elle a ouverte est par-dessus.
class BoutonVerre extends StatefulWidget {
  const BoutonVerre({super.key, required this.texte, this.onTap, this.plein = false, this.icone, this.iconeApres, this.large = true, this.widgetIcone, this.teinte, this.enCours = false});

  final String texte;
  final VoidCallback? onTap;
  final bool plein;

  /// Rouge (signaler, refuser) ou limonade (publier, en moderation) ; sinon
  /// l ocean si plein, le verre clair sinon.
  final TeinteVerre? teinte;
  final String? icone;
  final String? iconeApres;
  final bool large;
  final Widget? widgetIcone;

  /// L attente decidee par l ecran (en plus de celle de sa propre action).
  final bool enCours;

  @override
  State<BoutonVerre> createState() => _BoutonVerreState();
}

class _BoutonVerreState extends State<BoutonVerre> {
  bool _occupe = false;
  bool _visible = false;
  Timer? _delai;

  void _appui() {
    final r = (widget.onTap as Function?)?.call();
    if (r is! Future) return;
    setState(() => _occupe = true);
    _delai = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _visible = true);
    });
    r.whenComplete(() {
      _delai?.cancel();
      if (mounted) setState(() => _occupe = _visible = false);
    }).ignore();
  }

  @override
  void dispose() {
    _delai?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final masse = widget.teinte ?? (widget.plein ? TeinteVerre.ocean : TeinteVerre.clair);
    final couleur = switch (masse) {
      TeinteVerre.ocean || TeinteVerre.rouge => Colors.white,
      TeinteVerre.limonade || TeinteVerre.vert => Couleurs.encreLimonade,
      _ => Couleurs.texte,
    };
    final large = widget.large;
    // Le logo tourne seulement sur la page au premier plan.
    final tourne = widget.enCours || _occupe && _visible && (ModalRoute.of(context)?.isCurrent ?? true);
    final attend = widget.enCours || _occupe;
    final contenu = DefaultTextStyle.merge(
      style: Textes.bouton.copyWith(color: couleur, fontSize: large ? 15.5 : 14.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.widgetIcone != null) ...[widget.widgetIcone!, const SizedBox(width: 9)],
          if (widget.icone != null) ...[Icone(widget.icone!, taille: 19, couleur: couleur), const SizedBox(width: 9)],
          Flexible(child: Text(widget.texte, overflow: TextOverflow.ellipsis)),
          if (widget.iconeApres != null) ...[const SizedBox(width: 9), Icone(widget.iconeApres!, taille: 19, couleur: couleur)],
        ],
      ),
    );
    // Sur l ocean ou le rouge, la goutte est blanche ; sur la limonade, noire ; sinon, le theme.
    final logo = LogoQuiTourne(taille: large ? 24 : 20, sombre: couleur == Colors.white ? true : (masse == TeinteVerre.limonade || masse == TeinteVerre.vert ? false : null));
    return AnimatedOpacity(
      opacity: widget.onTap == null && !attend ? 0.38 : 1,
      duration: Durees.interface,
      child: Appuyable(
        onTap: widget.onTap == null || attend ? null : _appui,
        semantique: tourne ? t('{texte}, en cours', {'texte': widget.texte}) : widget.texte,
        verre: true,
        rayonVerre: Mesures.rayonBouton,
        gonflement: large ? 0.03 : 0.06,
        child: Verre(
          teinte: masse,
          child: SizedBox(
            height: large ? 46 : 38,
            width: large ? double.infinity : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: large ? 20 : 14),
              // Le texte garde sa place (le bouton ne change pas de largeur), le logo le remplace.
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(opacity: tourne ? 0 : 1, child: contenu),
                  if (tourne) logo,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// S'abonner : bleu tant qu on ne l est pas, vert avec une coche une fois abonne.
/// Le meme bouton partout (profil, photo, reels, notifications, reactions).
class BoutonAbonner extends StatelessWidget {
  const BoutonAbonner({super.key, required this.abonne, required this.onTap, this.large = false});

  final bool abonne;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) =>
      BoutonVerre(texte: abonne ? t('Abonné') : t('S’abonner'), teinte: abonne ? TeinteVerre.vert : TeinteVerre.ocean, icone: abonne ? 'coche' : null, large: large, onTap: onTap);
}

/// Envoyer, facon iOS : un rond bleu et une fleche blanche vers le haut. Gris
/// tant qu il n y a rien a envoyer ; des qu on ecrit, il se remplit avec un
/// petit rebond.
class BoutonEnvoyer extends StatelessWidget {
  const BoutonEnvoyer({super.key, required this.actif, required this.onTap, this.taille = 32});

  final bool actif;
  final VoidCallback onTap;
  final double taille;

  @override
  Widget build(BuildContext context) => Appuyable(
    semantique: t('Envoyer'),
    verre: true,
    rayonVerre: taille / 2,
    gonflement: 0.16,
    onTap: actif ? onTap : null,
    child: AnimatedScale(
      scale: actif ? 1 : 0.86,
      duration: const Duration(milliseconds: 420),
      curve: Courbes.ressort,
      child: AnimatedContainer(
        duration: Durees.interface,
        width: taille,
        height: taille,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: actif ? Couleurs.ocean : Couleurs.texte.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icone('fleche-haut', taille: taille * 0.62, couleur: actif ? Colors.white : Couleurs.discret),
      ),
    ),
  );
}

/// Le bouton rond : retour, recherche, notifications.
class RondVerre extends StatelessWidget {
  const RondVerre({super.key, required this.icone, required this.semantique, this.onTap, this.point = false, this.taille = 44, this.surPhoto = false, this.encre, this.lisible = false});

  final String icone;
  final String semantique;
  final VoidCallback? onTap;
  final bool point;
  final double taille;

  /// Pose sur une photo : le meme verre liquide, mais sans le fond de la
  /// page ni ombre portee dessous (elle ferait une tache grise a travers).
  final bool surPhoto;

  /// La couleur de l icone : l encre, ou blanc sur un fond sombre.
  final Color? encre;

  /// Sur une photo sombre, le verre seul laisse l icone noire se perdre : un fond blanc presque
  /// plein la garde lisible (le retour et « Plus d options » de la page photo).
  final bool lisible;

  @override
  Widget build(BuildContext context) => Appuyable(
    onTap: onTap,
    semantique: semantique,
    verre: true,
    rayonVerre: taille / 2,
    child: _fond(
      SizedBox(
        width: taille,
        height: taille,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (lisible)
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.86), shape: BoxShape.circle),
                child: SizedBox.square(dimension: taille),
              ),
            Icone(icone, taille: 22, couleur: encre ?? Couleurs.texte),
            if (point)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Couleurs.erreur,
                    shape: BoxShape.circle,
                    border: Border.all(color: Couleurs.fond, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _fond(Widget enfant) => Verre(rayon: taille / 2, surFond: !surPhoto, ombre: !surPhoto, child: enfant);
}

/// La pastille de filtre : un verre fin.
class Pastille extends StatelessWidget {
  const Pastille({super.key, required this.texte, this.icone, this.iconeApres, this.retenue = false, this.onTap});

  final String texte;
  final String? icone;
  final String? iconeApres;
  final bool retenue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = retenue ? Couleurs.surEncre : Couleurs.texte;
    return Appuyable(
      onTap: onTap ?? () {},
      semantique: texte,
      verre: true,
      rayonVerre: retenue ? null : 18,
      gonflement: 0.07,
      child: retenue
          ? Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Couleurs.texte, borderRadius: BorderRadius.circular(18)),
              child: _contenu(couleur),
            )
          : Verre(
              rayon: 18,
              child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 14), child: _contenu(couleur)),
            ),
    );
  }

  Widget _contenu(Color couleur) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icone != null) ...[Icone(icone!, taille: 18, couleur: couleur), const SizedBox(width: 7)],
      Text(
        texte,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: couleur),
      ),
      if (iconeApres != null) ...[const SizedBox(width: 6), Icone(iconeApres!, taille: 16, couleur: couleur)],
    ],
  );
}

/// Le badge d une capture : verifiee (limonade) ou declaree. Sur une carte
/// de mosaique, l icone seule suffit (`seul`) : elle dit deja « verifiee ».
class BadgeCapture extends StatelessWidget {
  const BadgeCapture({super.key, required this.verifie, this.court = false, this.seul = false});

  final bool verifie;

  /// « Vérifiée », plus petit (la fiche de capture).
  final bool court;

  /// L icone seule, dans sa pastille ronde (les cartes).
  final bool seul;

  @override
  Widget build(BuildContext context) {
    final encre = verifie ? Couleurs.encreLimonade : Couleurs.discret;
    final fond = verifie ? Couleurs.limonade : Couleurs.surface.withValues(alpha: 0.7);
    if (seul) {
      return Semantics(
        label: verifie ? t('Capture vérifiée') : t('Informations déclarées'),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
          child: Icone(verifie ? 'verifie' : 'alerte', taille: 17, couleur: encre),
        ),
      );
    }
    return Container(
      height: court ? 24 : 26,
      padding: EdgeInsets.fromLTRB(court ? 6 : 7, 0, court ? 9 : 10, 0),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icone(verifie ? 'verifie' : 'alerte', taille: court ? 15 : 16, couleur: encre),
          SizedBox(width: court ? 4 : 5),
          Text(
            verifie ? (court ? t('Vérifiée') : t('Capture vérifiée')) : (court ? t('Déclarée') : t('Informations déclarées')),
            style: TextStyle(fontSize: court ? 11.5 : 12.5, fontWeight: FontWeight.w600, color: encre),
          ),
        ],
      ),
    );
  }
}

/// La plaque : le support des informations et des listes (fiche de capture,
/// groupes de reglages, motifs), a plat comme les cartes des Parametres du
/// telephone ou de Bloc-notes. Un fond plein un ton au-dessus de la page,
/// des coins ronds, ni bord, ni ombre, ni relief. Le verre reste aux boutons
/// et a ce qui flotte.
class Plaque extends StatelessWidget {
  const Plaque({super.key, required this.child, this.rayon = Mesures.rayonPlaque, this.padding});

  final Widget child;
  final double rayon;
  final EdgeInsetsGeometry? padding;

  // Decoupee a son arrondi : l encre d une ligne touchee suit les coins de la carte.
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(rayon),
    child: DecoratedBox(
      decoration: BoxDecoration(color: Couleurs.plaque),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    ),
  );
}
