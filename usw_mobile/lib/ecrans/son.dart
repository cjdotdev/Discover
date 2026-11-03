// La page d un son, comme sur TikTok : sa pochette, son titre, son auteur et sa licence, l ecoute,
// les favoris, les reels qui l utilisent (les plus aimes d abord) et « Utiliser ce son », qui ouvre
// l appareil photo puis le montage avec ce son deja choisi.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../donnees/communaute.dart';
import '../donnees/modeles.dart';
import '../donnees/sons.dart';
import '../outils/chemins.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/banniere.dart';
import '../widgets/icone.dart';
import '../widgets/photo.dart';
import '../widgets/sons.dart';
import '../widgets/verre.dart';
import 'creer.dart' show tournerAvecLeSon;
import 'etats.dart';

class EcranSon extends StatefulWidget {
  const EcranSon({super.key, required this.id});

  final String id;

  @override
  State<EcranSon> createState() => _EcranSonState();
}

class _EcranSonState extends State<EcranSon> {
  Son? _son;
  bool _introuvable = false;
  List<Reel> _reels = const [];
  String? _suite;
  bool _charge = false;
  final _defile = ScrollController();

  @override
  void initState() {
    super.initState();
    _defile.addListener(() {
      if (_defile.position.pixels > _defile.position.maxScrollExtent - 400) _plus();
    });
    _charger();
  }

  @override
  void dispose() {
    _defile.dispose();
    unawaited(EcouteSon.instance.arreter());
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final s = await Sons.instance.son(widget.id);
      final r = await Sons.instance.reels(widget.id);
      if (!mounted) return;
      setState(() {
        _son = s;
        _reels = r.reels;
        _suite = r.suite;
      });
    } catch (_) {
      if (mounted) setState(() => _introuvable = true);
    }
  }

  Future<void> _plus() async {
    final suite = _suite;
    if (suite == null || _charge) return;
    _charge = true;
    try {
      final r = await Sons.instance.reels(widget.id, curseur: suite);
      if (mounted) {
        setState(() {
          _reels = [..._reels, ...r.reels];
          _suite = r.suite;
        });
      }
    } catch (_) {}
    _charge = false;
  }

  Future<void> _favori() async {
    final s = _son;
    if (s == null) return;
    if (!Communaute.instance.enLigne) return bulle(context, t('Connectez-vous pour garder ce son.'), icone: 'profil');
    final garder = !s.favori;
    setState(() => _son = s.avecFavori(garder));
    try {
      await Sons.instance.favori(s.id, garder);
      if (mounted) bulle(context, garder ? t('Ajouté à vos favoris.') : t('Retiré de vos favoris.'), icone: 'enregistrer');
    } catch (_) {
      if (!mounted) return;
      setState(() => _son = s);
      bulle(context, t('Impossible pour le moment. Réessayez.'), icone: 'alerte');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_introuvable) return const EcranEtat(etat: 'introuvable');
    final s = _son;
    final haut = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: s == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : CustomScrollView(
              controller: _defile,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, haut + 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: _entete(s)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(2, 20, 2, 120),
                  sliver: _reels.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(t('Aucun reel avec ce son pour l’instant. Soyez le premier.'), textAlign: TextAlign.center, style: Textes.discret),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 9 / 16),
                          delegate: SliverChildBuilderDelegate((context, i) => _Vignette(reel: _reels[i]), childCount: _reels.length),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _entete(Son s) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: EcouteSon.instance.enCours,
            builder: (context, joue, _) => GestureDetector(
              onTap: () => joue == s.id ? EcouteSon.instance.arreter() : EcouteSon.instance.ecouter(s),
              child: Semantics(
                button: true,
                label: joue == s.id ? t('Arrêter l’écoute') : t('Écouter'),
                child: Pochette(son: s, taille: 96, enLecture: joue == s.id),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.titre, style: Textes.sousTitre),
                const SizedBox(height: 4),
                Text(s.artiste, style: Textes.discret),
                const SizedBox(height: 4),
                Text([dureeSon(s.dureeMs), tn(s.nombreReels, '{n} reel', '{n} reels')].join(' · '), style: Textes.petit),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: BoutonVerre(
              texte: t('Utiliser ce son'),
              icone: 'reels',
              plein: true,
              onTap: s.actif ? () => tournerAvecLeSon(context, s) : () => bulle(context, t('Ce son n’est plus disponible.'), icone: 'alerte'),
            ),
          ),
          const SizedBox(width: 10),
          RondVerre(icone: s.favori ? 'coche' : 'enregistrer', semantique: s.favori ? t('Retirer des favoris') : t('Ajouter aux favoris'), onTap: _favori),
        ],
      ),
      const SizedBox(height: 12),
      // Ce que la licence demande : le titre, l auteur et la licence, avec son lien.
      GestureDetector(
        onTap: s.licenceUrl == null ? null : () => launchUrl(Uri.parse(s.licenceUrl!), mode: LaunchMode.externalApplication),
        child: Text(s.attribution, style: Textes.petit),
      ),
      // Un son importe par un membre : le signaler (les droits, son contenu).
      if (s.importe && Communaute.instance.enLigne)
        GestureDetector(
          onTap: () async {
            try {
              await Sons.instance.signaler(s.id);
              if (mounted) bulle(context, t('Merci. Ce son sera examiné.'), icone: 'drapeau');
            } catch (_) {
              if (mounted) bulle(context, t('Impossible pour le moment. Réessayez.'), icone: 'alerte');
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(t('Signaler ce son'), style: Textes.petit.copyWith(decoration: TextDecoration.underline)),
          ),
        ),
    ],
  );
}

class _Vignette extends StatelessWidget {
  const _Vignette({required this.reel});

  final Reel reel;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: reel.id == null ? null : () => context.push(ici(context, 'lieu/_/photo/${reel.id}')),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Couleurs.photoVide, child: Photo(reel.photo)),
        Positioned(
          left: 6,
          bottom: 6,
          child: Row(
            children: [
              const Icone('lecture', taille: 13, couleur: Colors.white),
              const SizedBox(width: 3),
              Text(
                '${reel.vues}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
