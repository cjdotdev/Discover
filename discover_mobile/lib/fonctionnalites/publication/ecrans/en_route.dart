// E16 En route (repris de « Mes envois » de usw_mobile) : les envois en cours, en
// vérification et terminés. Un envoi coupé reprend où il s'était arrêté ; on le met
// en pause ou on l'annule. Une publication refusée (E37) dit pourquoi et propose
// de demander une vérification.
// À brancher : HEAD envois/{envoi} et PATCH envois/{envoi}.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../../socle/widgets/page_formulaire.dart';
import '../../decouverte/widgets/jetons.dart';
import '../../decouverte/widgets/photo.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/envois.dart';
import '../widgets/plaque.dart';

/// E16 En route. Voir repartition.md.
class EcranEnRoute extends StatelessWidget {
  const EcranEnRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Envois.instance,
        builder: (context, _) {
          final liste = Envois.instance.liste;
          Widget groupe(String titre, Iterable<Envoi> envois) => envois.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
                      child: Text(titre, style: Textes.libelle.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
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
                child: RondVerre(
                  icone: 'retour',
                  semantique: 'Retour',
                  onTap: () => context.canPop() ? context.pop() : context.go(Routes.accueil),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(header: true, child: const Text('Mes envois', style: Textes.titre)),
              const SizedBox(height: 8),
              const Text(
                "Un envoi coupé reprend où il s'était arrêté, dès que le réseau revient.",
                style: Textes.discret,
              ),
              const SizedBox(height: 18),
              groupe('En cours', liste.where((e) => e.etat == EtatEnvoi.encours || e.etat == EtatEnvoi.pause)),
              groupe('En vérification', liste.where((e) => e.etat == EtatEnvoi.verification)),
              groupe('Terminés', liste.where((e) => e.etat == EtatEnvoi.publie || e.etat == EtatEnvoi.refuse)),
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
      EtatEnvoi.encours => (
        '$pct % · $envoye Mo sur ${e.poidsMo.toStringAsFixed(1).replaceAll('.', ',')} Mo · 3G',
        null,
        null,
      ),
      EtatEnvoi.pause => ('En pause · $pct %${e.detail != null ? ' · ${e.detail}' : ''}', null, null),
      EtatEnvoi.verification => ("Recherche des signes d'IA · environ 1 min", null, null),
      EtatEnvoi.publie => (e.detail ?? 'Publiée', 'verifie', null),
      EtatEnvoi.refuse => (e.detail ?? 'Refusée', 'drapeau', Couleurs.erreur),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Plaque(
        rayon: 20,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(width: 48, height: 60, child: PhotoArrondie(e.photo, rayon: 10)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.titre, style: Textes.libelle.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (icone != null) ...[Icone(icone, taille: 14, couleur: couleur), const SizedBox(width: 4)],
                      Expanded(
                        child: Text(detail, style: Textes.petit.copyWith(fontSize: 12.5, color: couleur)),
                      ),
                    ],
                  ),
                  if (e.etat == EtatEnvoi.encours || e.etat == EtatEnvoi.pause) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: e.avance,
                        minHeight: 4,
                        color: e.etat == EtatEnvoi.pause ? Couleurs.discret : Couleurs.ocean,
                        backgroundColor: Teintes.filet,
                      ),
                    ),
                  ],
                  if (e.etat == EtatEnvoi.verification) ...[const SizedBox(height: 6), const _LogoQuiTourne()],
                ],
              ),
            ),
            if (e.etat == EtatEnvoi.encours || e.etat == EtatEnvoi.pause) ...[
              const SizedBox(width: 8),
              RondVerre(
                icone: e.etat == EtatEnvoi.pause ? 'lecture' : 'pause',
                semantique: e.etat == EtatEnvoi.pause ? 'Reprendre' : 'Mettre en pause',
                taille: 38,
                onTap: () => Envois.instance.basculer(e),
              ),
              const SizedBox(width: 4),
              RondVerre(
                icone: 'fermer',
                semantique: "Annuler l'envoi",
                taille: 38,
                encre: Couleurs.erreur,
                onTap: () => Envois.instance.annuler(e),
              ),
            ],
            if (e.etat == EtatEnvoi.refuse)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _EcranRefusee(titre: e.titre))),
                child: Text('Motif', style: Textes.libelle.copyWith(decoration: TextDecoration.underline)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le logo qui tourne : l'attente de la vérification.
class _LogoQuiTourne extends StatefulWidget {
  const _LogoQuiTourne();

  @override
  State<_LogoQuiTourne> createState() => _LogoQuiTourneState();
}

class _LogoQuiTourneState extends State<_LogoQuiTourne> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final Animation<double> _tours = Tween<double>(begin: 0, end: -1).animate(_c);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mouvements réduits : le logo reste immobile.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Vérification en cours',
    child: ExcludeSemantics(
      child: RotationTransition(turns: _tours, child: const Logo(taille: 18)),
    ),
  );
}

/// E37 Publication refusée : ce qui a été vu, et le recours.
class _EcranRefusee extends StatefulWidget {
  const _EcranRefusee({required this.titre});

  final String titre;

  @override
  State<_EcranRefusee> createState() => _EcranRefuseeState();
}

class _EcranRefuseeState extends State<_EcranRefusee> {
  bool _demande = false;

  @override
  Widget build(BuildContext context) => PageFormulaire(
    titre: 'Publication refusée',
    entete: Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Couleurs.erreur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icone('drapeau', taille: 32, couleur: Couleurs.erreur),
    ),
    sousTitre: Text(
      "« ${widget.titre} » contient des signes d'image générée par IA. Si c'est une vraie photo, "
      "demandez une vérification par l'équipe : la réponse arrive sous 48 h.",
    ),
    children: [
      BoutonVerre(
        texte: _demande ? 'Demande envoyée' : 'Demander une vérification',
        plein: !_demande,
        icone: _demande ? 'coche' : null,
        onTap: _demande
            ? null
            : () {
                setState(() => _demande = true);
                bulle(context, "Demande envoyée. L'équipe vous répond sous 48 h.");
              },
      ),
      const SizedBox(height: 10),
      // Les règles (E23) sont hors du MVP : un simple message.
      BoutonVerre(texte: 'Lire les règles', onTap: () => bulle(context, 'Les règles arrivent bientôt.')),
    ],
  );
}
