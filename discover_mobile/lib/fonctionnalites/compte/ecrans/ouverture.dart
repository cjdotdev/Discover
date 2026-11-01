import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/session/session.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';

/// E00 Ouverture : le logo apparaît, la phrase s'écrit lettre après lettre, puis on part.
class EcranOuverture extends StatefulWidget {
  const EcranOuverture({super.key});

  @override
  State<EcranOuverture> createState() => _EcranOuvertureState();
}

class _EcranOuvertureState extends State<EcranOuverture> with SingleTickerProviderStateMixin {
  static const _phrase = 'Let’s Discover';

  late final AnimationController _temps = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _temps.forward().whenComplete(() {
      if (mounted) context.go(Session.instance.destination);
    });
  }

  @override
  void dispose() {
    _temps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _temps,
          builder: (context, _) {
            final logo = Courbes.signature.transform((_temps.value / 0.4).clamp(0, 1));
            final lettres = (((_temps.value - 0.3) / 0.6).clamp(0, 1) * _phrase.length).round();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: logo,
                  child: Transform.scale(scale: 0.8 + 0.2 * logo, child: const Logo(taille: 72)),
                ),
                const SizedBox(height: 18),
                Text(_phrase.substring(0, lettres), style: Textes.titre),
              ],
            );
          },
        ),
      ),
    );
  }
}
