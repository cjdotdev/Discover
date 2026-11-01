import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/api/erreur_api.dart';
import '../../../socle/session/session.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/bouton.dart';
import '../../../socle/widgets/messages.dart';
import '../../../socle/widgets/progression.dart';
import '../donnees/depot_compte.dart';
import '../donnees/profil.dart';
import '../widgets/etape_gouts.dart';
import '../widgets/etape_identite.dart';
import '../widgets/etape_lieu.dart';

/// E36 Compléter le profil, à la première connexion : identité, lieu, goûts.
/// Les trois étapes remplissent le même objet `Profil`, envoyé à la fin.
class EcranCompleterProfil extends StatefulWidget {
  const EcranCompleterProfil({super.key});

  @override
  State<EcranCompleterProfil> createState() => _EcranCompleterProfilState();
}

class _EcranCompleterProfilState extends State<EcranCompleterProfil> {
  static const _total = 3;

  final _profil = Profil();
  int _etape = 0;
  bool _attente = false;

  void _suivante() => setState(() => _etape++);

  Future<void> _terminer() async {
    setState(() => _attente = true);
    try {
      await depotCompte.enregistrerProfil(_profil);
      if (mounted) context.go(Session.instance.destination);
    } on ErreurApi catch (erreur) {
      if (mounted) bulle(context, erreur.message);
    } on ApiInjoignable {
      if (mounted) bulle(context, 'Aucune connexion. Vérifiez le réseau, puis réessayez.');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurFormulaire),
            child: Padding(
              padding: EdgeInsets.fromLTRB(marge, 8, marge, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Progression(etape: _etape, total: _total),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_etape > 0) ...[
                        BoutonRond(icone: 'retour', semantique: 'Retour', onTap: () => setState(() => _etape--)),
                        const SizedBox(width: 12),
                      ],
                      Text('Étape ${_etape + 1} sur $_total', style: Textes.libelle),
                      const Spacer(),
                      if (_etape == _total - 1) Lien('Passer', discret: true, onTap: _attente ? null : _terminer),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: switch (_etape) {
                      0 => EtapeIdentite(profil: _profil, surSuite: _suivante),
                      1 => EtapeLieu(profil: _profil, surSuite: _suivante),
                      _ => EtapeGouts(profil: _profil, attente: _attente, surFin: _terminer),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
