// E00 Ouverture : « Let’s Discover ». Le logo arrive en tournant, puis la
// phrase s ecrit lettre apres lettre, d une encre unie (noire sur le jour,
// blanche la nuit). Pendant que le logo tourne, ses couleurs (le bleu, le
// citron) traversent la phrase comme un pouls, puis s en vont : il ne reste que
// l encre. Enfin l ecran se leve comme un rideau et decouvre la bienvenue, deja
// la dessous : elle arrive pendant que le rideau monte, sans changer de page.
// La bienvenue ne se voit qu au premier lancement ; ensuite, l ouverture mene
// a l accueil (connecte) ou a l entree, comme WhatsApp.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../donnees/push.dart';
import '../donnees/session.dart';
import '../theme/jetons.dart';
import '../widgets/icone.dart';
import '../widgets/mouvement.dart';
import 'bienvenue.dart';

class EcranOuverture extends StatefulWidget {
  const EcranOuverture({super.key});

  @override
  State<EcranOuverture> createState() => _EcranOuvertureState();
}

class _EcranOuvertureState extends State<EcranOuverture> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600));
  late final AnimationController _rideau = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _leve = CurvedAnimation(parent: _rideau, curve: Courbes.signature);
  Timer? _suite;

  /// La bienvenue est montee sous le rideau quand il commence a se lever.
  bool _dessous = false;

  /// Le rideau est parti : il ne reste que la bienvenue.
  bool _parti = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _suite = Timer(const Duration(milliseconds: 4900), _lever);
    _rideau.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _parti = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (animationsReduites(context)) _c.value = 1;
  }

  void _lever() {
    if (!mounted) return;
    final s = Session.instance;
    if (s.bienvenueVue) {
      context.go(s.destination);
      // Discover ouvert en touchant une notification : son centre, par-dessus l accueil.
      final page = Push.instance.arrive();
      if (page != null && s.destination == '/accueil') context.push(page);
      return;
    }
    s.marquerBienvenueVue();
    setState(() => _dessous = true);
    if (animationsReduites(context)) {
      _rideau.value = 1;
    } else {
      _rideau.forward();
    }
  }

  @override
  void dispose() {
    _suite?.cancel();
    _c.dispose();
    _rideau.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // Toujours a la meme place dans la pile : elle garde son etat quand
      // le rideau s en va.
      if (_dessous)
        AnimatedBuilder(
          animation: _leve,
          builder: (context, child) => Transform.translate(offset: Offset(0, 48 * (1 - _leve.value)), child: child),
          child: const EcranBienvenue(),
        )
      else
        ColoredBox(color: Couleurs.fond, child: const SizedBox.expand()),
      if (!_parti)
        AnimatedBuilder(
          animation: _leve,
          builder: (context, child) {
            final v = _leve.value;
            final rayon = Radius.circular(32 * (v * 6).clamp(0.0, 1.0));
            return FractionalTranslation(
              translation: Offset(0, -v),
              // Un filet sous le bord du rideau : les deux ecrans ont le meme fond.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: v > 0 ? Couleurs.voile : null,
                  borderRadius: BorderRadius.vertical(bottom: rayon),
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: v > 0 ? 1 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(bottom: rayon),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: _rideauOuverture(context),
        ),
    ],
  );

  // Une tranche de l animation, en secondes, sur la courbe souple.
  Animation<double> _tranche(double debut, double duree) => CurvedAnimation(
    parent: _c,
    curve: Interval(debut / 4.6, ((debut + duree) / 4.6).clamp(0, 1), curve: Courbes.souple),
  );

  Widget _rideauOuverture(BuildContext context) {
    final taille = (MediaQuery.sizeOf(context).width * 0.1).clamp(34.0, 72.0);
    // Une encre unie : noire sur le jour, blanche la nuit.
    final encre = Couleurs.sombre ? Colors.white : Colors.black;
    final style = TextStyle(fontSize: taille, fontWeight: FontWeight.w700, letterSpacing: -0.03 * taille, color: encre, height: 1.1);
    const phrase = 'Let’s Discover';
    final lettres = phrase.characters.toList();

    // L ecriture : chaque lettre monte et apparait un peu apres la precedente.
    const debutEcriture = 0.55, pas = 0.085, dureeLettre = 0.5;
    Widget lettre(int i) {
      final t = _tranche(debutEcriture + i * pas, dureeLettre);
      return AnimatedBuilder(
        animation: t,
        builder: (context, child) => Opacity(
          opacity: t.value,
          child: Transform.translate(offset: Offset(0, (1 - t.value) * taille * 0.35), child: child),
        ),
        child: Text(lettres[i], style: style),
      );
    }

    // Le pouls des couleurs du logo, une fois la phrase ecrite : une vague bleue
    // puis citron qui traverse de gauche a droite, et repart.
    final pouls = CurvedAnimation(
      parent: _c,
      curve: const Interval(2.45 / 4.6, 3.95 / 4.6, curve: Curves.easeInOutCubic),
    );

    final logo = _tranche(0, 0.9);
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Let’s Discover',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: logo,
                  // A l arrivee, un demi-tour de plus qui ralentit : le logo
                  // entre lance, puis garde son tour tranquille.
                  builder: (context, child) => Opacity(
                    opacity: logo.value,
                    child: Transform.rotate(
                      angle: -math.pi * logo.value,
                      child: Transform.scale(scale: 0.85 + 0.15 * logo.value, child: child),
                    ),
                  ),
                  child: const LogoQuiTourne(taille: 72, tour: Duration(milliseconds: 2400)),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    child: AnimatedBuilder(
                      animation: pouls,
                      builder: (context, child) {
                        final v = pouls.value;
                        if (v <= 0 || v >= 1) return child!;
                        // Le centre de la vague va de -0.4 a 1.4 : elle entre et sort entiere.
                        final c = -0.4 + 1.8 * v;
                        double a(double x) => x.clamp(0.0, 1.0);
                        return ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bord) => LinearGradient(
                            colors: [encre, encre, Couleurs.ocean, Couleurs.limonade, encre, encre],
                            stops: [0, a(c - 0.32), a(c - 0.1), a(c + 0.1), a(c + 0.32), 1],
                          ).createShader(bord),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [for (var i = 0; i < lettres.length; i++) lettre(i)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
