// Lieux enregistres : les lieux gardes depuis leur page (Enregistrer), en piles
// comme a l accueil, les plus recents d abord (GET moi/lieux). Toucher une pile
// ouvre son lieu.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../donnees/communaute.dart';
import '../donnees/lieux_enregistres.dart';
import '../donnees/modeles.dart';
import '../outils/chemins.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';
import 'etats.dart';

class EcranLieuxEnregistres extends StatefulWidget {
  const EcranLieuxEnregistres({super.key});

  @override
  State<EcranLieuxEnregistres> createState() => _EcranLieuxEnregistresState();
}

class _EcranLieuxEnregistresState extends State<EcranLieuxEnregistres> {
  // Nul : la premiere page n est pas encore arrivee.
  List<Lieu>? _lieux;
  String? _suite;
  bool _charge = false;
  bool _horsLigne = false;

  @override
  void initState() {
    super.initState();
    LieuxEnregistres.instance.addListener(_change);
    _charger();
  }

  @override
  void dispose() {
    LieuxEnregistres.instance.removeListener(_change);
    super.dispose();
  }

  // Un lieu enregistre ou retire depuis sa page : la liste suit.
  void _change() {
    final lieux = _lieux;
    if (!mounted || lieux == null) return;
    final retires = lieux.where((l) => LieuxEnregistres.instance.estEnregistre(l.id) == false).length;
    if (retires > 0) setState(() => lieux.removeWhere((l) => LieuxEnregistres.instance.estEnregistre(l.id) == false));
    // Un nouveau lieu se place en tete : la liste repart du debut.
    if (retires == 0) _charger();
  }

  Future<void> _charger() async {
    if (!Communaute.instance.enLigne || _charge) return;
    _charge = true;
    final p = await LieuxEnregistres.instance.page();
    _charge = false;
    if (!mounted) return;
    setState(() {
      _horsLigne = p == null && _lieux == null;
      if (p != null) {
        _lieux = p.lieux;
        _suite = p.suite;
      }
    });
    // Des lieux dont toutes les photos ont ete supprimees : ils ont quitte la liste, on le dit.
    final retires = p?.retires ?? const <String>[];
    if (retires.isNotEmpty) {
      bulle(
        context,
        retires.length == 1 && retires.first.isNotEmpty
            ? t('« {nom} » a été retiré de vos lieux enregistrés : ses photos ont été supprimées.', {'nom': retires.first})
            : tn(
                retires.length,
                '{n} lieu a été retiré de vos lieux enregistrés : ses photos ont été supprimées.',
                '{n} lieux ont été retirés de vos lieux enregistrés : leurs photos ont été supprimées.',
              ),
        icone: 'poubelle',
      );
    }
  }

  // Le bas de la liste approche : la page suivante.
  Future<void> _plus() async {
    final curseur = _suite;
    if (curseur == null || _charge) return;
    _charge = true;
    final p = await LieuxEnregistres.instance.page(curseur);
    _charge = false;
    if (!mounted || p == null) return;
    setState(() {
      _lieux = [
        ...?_lieux,
        for (final l in p.lieux)
          if (!(_lieux ?? const []).any((x) => x.id == l.id)) l,
      ];
      _suite = p.suite;
    });
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final lieux = _lieux;
    final Widget corps;
    if (!Communaute.instance.enLigne) {
      corps = EtatVide(
        icone: 'profil',
        titre: t('Lieux enregistrés'),
        texte: t('Connectez-vous pour retrouver ici les lieux que vous enregistrez.'),
        action: t('Se connecter'),
        onAction: () => context.push('/entree'),
      );
    } else if (_horsLigne) {
      corps = EtatVide(
        icone: 'hors-ligne',
        titre: t('Aucune connexion'),
        texte: t('Vos lieux enregistrés s’afficheront dès que le réseau sera rétabli.'),
        action: t('Réessayer'),
        onAction: () {
          setState(() => _horsLigne = false);
          _charger();
        },
      );
    } else if (lieux == null) {
      corps = const Center(child: LogoQuiTourne(taille: 34));
    } else if (lieux.isEmpty) {
      corps = EtatVide(icone: 'enregistrer', titre: t('Aucun lieu enregistré'), texte: t('Touchez Enregistrer sur la page d’un lieu pour le retrouver ici.'));
    } else {
      corps = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) _plus();
          return false;
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, 4, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
          children: [_Piles(lieux: lieux)],
        ),
      );
    }
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/profil')),
                const SizedBox(height: 14),
                Titre(t('Lieux enregistrés'), style: Textes.titre),
              ],
            ),
          ),
          Expanded(child: corps),
        ],
      ),
    );
  }
}

/// Les piles, sur deux colonnes.
class _Piles extends StatelessWidget {
  const _Piles({required this.lieux});

  final List<Lieu> lieux;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var c = 0; c < 2; c++) ...[
        if (c > 0) const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              for (var i = c; i < lieux.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Appuyable(
                    semantique: '${lieux[i].nom}, ${nombrePublications(lieux[i].nombre)}',
                    onTap: () => context.push(ici(context, 'lieu/${lieux[i].id}')),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: lieux[i].ratio,
                          child: lieux[i].photos.isEmpty ? const PhotoArrondie('') : Pile(photos: lieux[i].photos),
                        ),
                        const SizedBox(height: 7),
                        Text(lieux[i].nom, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25)),
                        Text([if (lieux[i].region.isNotEmpty) lieux[i].region, nombrePublications(lieux[i].nombre)].join(' · '), style: TextStyle(fontSize: 12, color: Couleurs.discret)),
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
