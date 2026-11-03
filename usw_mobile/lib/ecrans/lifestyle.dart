// Le lifestyle : l album de vie de chaque membre (ce qu il vit, mange, fait, ses lieux). Ses
// publications ne passent pas a l accueil de Discover. Mon lifestyle (depuis mon profil) : le
// rendre visible ou non, ajouter des photos et des videos, mes brouillons, ce qui est en ligne.
// Les lifestyles visibles (depuis la Recherche) : la pile de chaque membre ; la toucher ouvre le sien.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../donnees/communaute.dart';
import '../donnees/envois.dart';
import '../donnees/lieux_enregistres.dart' show nombrePublications;
import '../donnees/lifestyle.dart';
import '../donnees/modeles.dart';
import '../outils/chemins.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/champ.dart';
import '../widgets/feuille.dart';
import '../widgets/icone.dart';
import '../widgets/mosaique.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';
import 'creer.dart' show ouvrirCreerPourLifestyle;
import 'etats.dart';

/// L en-tete commun : le retour, puis le titre.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.fromLTRB(marge, MediaQuery.paddingOf(context).top + 8, marge, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/profil')),
          const SizedBox(height: 14),
          Titre(titre, style: Textes.titre),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ mon lifestyle

class EcranMonLifestyle extends StatefulWidget {
  const EcranMonLifestyle({super.key});

  @override
  State<EcranMonLifestyle> createState() => _EcranMonLifestyleState();
}

class _EcranMonLifestyleState extends State<EcranMonLifestyle> {
  // Les envois de mon lifestyle deja en ligne : un de plus, la liste se relit.
  int _enLigne = 0;

  @override
  void initState() {
    super.initState();
    Envois.instance.addListener(_envois);
    _enLigne = _envoisEnLigne();
    Lifestyle.instance.rafraichir();
  }

  @override
  void dispose() {
    Envois.instance.removeListener(_envois);
    super.dispose();
  }

  Iterable<Envoi> get _miens => Envois.instance.liste.where((e) => e.source?.portee == 'lifestyle');

  int _envoisEnLigne() => _miens.where((e) => e.etat == EtatEnvoi.publie).length;

  void _envois() {
    final n = _envoisEnLigne();
    if (n != _enLigne) {
      _enLigne = n;
      unawaited(Lifestyle.instance.rafraichir());
    }
    if (mounted) setState(() {});
  }

  Future<void> _regler(bool visible) async {
    final ok = await Lifestyle.instance.regler(visible: visible);
    if (!mounted) return;
    if (!ok) {
      bulle(context, t('Impossible de modifier ce réglage pour le moment. Réessayez.'), icone: 'alerte');
    } else {
      bulle(context, visible ? t('Votre lifestyle est visible des autres membres.') : t('Votre lifestyle n’est visible que par vous.'), icone: visible ? 'oeil' : 'cadenas');
    }
  }

  void _brouillon(BrouillonLifestyle b) => montrerFeuille<void>(
    context,
    titre: t('Brouillon'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(
            icone: 'envoyer',
            texte: t('Publier dans mon lifestyle'),
            onTap: () {
              Navigator.pop(f);
              Lifestyle.instance.publier(b);
              bulle(context, t('Publication lancée dans votre lifestyle.'));
            },
          ),
          _Option(
            icone: 'crayon',
            texte: t('Modifier la légende'),
            onTap: () {
              Navigator.pop(f);
              _legender(b);
            },
          ),
          _Option(
            icone: 'poubelle',
            texte: t('Supprimer le brouillon'),
            danger: true,
            onTap: () {
              Navigator.pop(f);
              Lifestyle.instance.supprimer(b);
            },
          ),
        ],
      ),
    ),
  );

  void _legender(BrouillonLifestyle b) {
    final champ = TextEditingController(text: b.source.legende);
    montrerFeuille<void>(
      context,
      titre: t('Légende'),
      contenu: (f) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChampVerre(libelle: t('Légende'), icone: 'crayon', indice: t('Facultatif'), controleur: champ, lignes: 3),
            const SizedBox(height: 14),
            BoutonVerre(
              texte: t('Enregistrer'),
              plein: true,
              onTap: () {
                Navigator.pop(f);
                Lifestyle.instance.legender(b, champ.text);
              },
            ),
          ],
        ),
      ),
    ).whenComplete(champ.dispose);
  }

  void _toutPublier() {
    final n = Lifestyle.instance.brouillons.length;
    for (final b in List.of(Lifestyle.instance.brouillons)) {
      Lifestyle.instance.publier(b);
    }
    bulle(context, tn(n, 'Publication lancée dans votre lifestyle.', '{n} publications lancées dans votre lifestyle.'));
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Lifestyle.instance,
        builder: (context, _) {
          final l = Lifestyle.instance;
          final miennes = l.miennes;
          final enCours = _miens.where((e) => e.etat == EtatEnvoi.encours || e.etat == EtatEnvoi.verification || e.etat == EtatEnvoi.pause).length;
          return RefreshIndicator(
            onRefresh: l.rafraichir,
            child: ListView(
              padding: EdgeInsets.only(bottom: Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
              children: [
                _EnTete(titre: t('Mon lifestyle')),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: marge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Plaque(
                        child: MergeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                            child: Row(
                              children: [
                                Icone(l.visible == true ? 'oeil' : 'cadenas', taille: 22, couleur: Couleurs.texte),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t('Visible par les autres membres'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        l.visible == true ? t('Il apparaît dans la recherche et sur votre profil.') : t('Pour l’instant, vous seul le voyez.'),
                                        style: TextStyle(fontSize: 13, color: Couleurs.discret),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: l.visible == true,
                                  activeTrackColor: Couleurs.ocean,
                                  inactiveTrackColor: Couleurs.pisteEteinte,
                                  inactiveThumbColor: Colors.white,
                                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                                  onChanged: l.visible == null ? null : _regler,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      BoutonVerre(texte: t('Ajouter des photos ou des vidéos'), icone: 'plus', plein: true, onTap: () => ouvrirCreerPourLifestyle(context)),
                      if (enCours > 0) ...[
                        const SizedBox(height: 6),
                        Lien(tn(enCours, '{n} publication en cours d’envoi', '{n} publications en cours d’envoi'), onTap: () => context.push('/creer/envois')),
                      ],
                      if (l.brouillons.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(tn(l.brouillons.length, '{n} brouillon', '{n} brouillons'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            ),
                            Lien(t('Tout publier'), onTap: _toutPublier),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3 / 4,
                          children: [
                            for (final b in l.brouillons)
                              Appuyable(
                                semantique: b.source.legende.isEmpty ? t('Brouillon') : b.source.legende,
                                onTap: () => _brouillon(b),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    PhotoArrondie(b.couverture, rayon: 14),
                                    if (b.source.reel) const Center(child: Icone('lecture', taille: 28, couleur: Colors.white)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (miennes == null)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: LogoQuiTourne(taille: 30)),
                        )
                      else if (miennes.isEmpty && l.brouillons.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Text(t('Rien encore.'), style: Textes.discret, textAlign: TextAlign.center),
                        )
                      else if (miennes.isNotEmpty) ...[
                        Text(tn(miennes.length, '{n} publication', '{n} publications'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        MosaiquePublications(publications: miennes, titre: (_) => '', onTap: (i) => context.push(ici(context, 'lieu/_/photo/${miennes[i].id}'))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icone, required this.texte, required this.onTap, this.danger = false});

  final String icone;
  final String texte;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Icone(icone, taille: 22, couleur: danger ? Couleurs.erreur : Couleurs.texte),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: danger ? Couleurs.erreur : Couleurs.texte),
            ),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------ les lifestyles (la recherche)

class EcranLifestyles extends StatefulWidget {
  const EcranLifestyles({super.key});

  @override
  State<EcranLifestyles> createState() => _EcranLifestylesState();
}

class _EcranLifestylesState extends State<EcranLifestyles> {
  List<LifestyleDeMembre>? _membres;
  String? _suite;
  bool _charge = false;
  bool _horsLigne = false;
  final _q = TextEditingController();
  Timer? _attente;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    _charge = true;
    final q = _q.text;
    final p = await Lifestyle.instance.membres(q: q);
    _charge = false;
    if (!mounted || q != _q.text) return;
    setState(() {
      _horsLigne = p == null && _membres == null;
      if (p != null) {
        _membres = p.membres;
        _suite = p.suite;
      }
    });
  }

  Future<void> _plus() async {
    final curseur = _suite;
    if (curseur == null || _charge) return;
    _charge = true;
    final p = await Lifestyle.instance.membres(q: _q.text, curseur: curseur);
    _charge = false;
    if (!mounted || p == null) return;
    setState(() {
      _membres = [...?_membres, ...p.membres];
      _suite = p.suite;
    });
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final membres = _membres;
    final Widget corps;
    if (_horsLigne) {
      corps = EtatVide(
        icone: 'hors-ligne',
        titre: t('Aucune connexion'),
        texte: t('Les lifestyles s’afficheront dès que le réseau sera rétabli.'),
        action: t('Réessayer'),
        onAction: () {
          setState(() => _horsLigne = false);
          _charger();
        },
      );
    } else if (membres == null) {
      corps = const Center(child: LogoQuiTourne(taille: 34));
    } else if (membres.isEmpty) {
      corps = EtatVide(
        icone: 'profil',
        titre: _q.text.trim().isEmpty ? t('Aucun lifestyle pour le moment') : t('Aucun résultat'),
        texte: '',
        action: Communaute.instance.enLigne ? t('Créer mon lifestyle') : null,
        onAction: Communaute.instance.enLigne ? () => context.push('/profil/lifestyle') : null,
      );
    } else {
      corps = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) _plus();
          return false;
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, 4, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
          children: [_Piles(membres: membres)],
        ),
      );
    }
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EnTete(titre: t('Lifestyle')),
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 0, marge, 12),
            child: ChampVerre(
              libelle: t('Rechercher un membre'),
              icone: 'loupe',
              controleur: _q,
              onChanged: (_) {
                _attente?.cancel();
                _attente = Timer(const Duration(milliseconds: 350), _charger);
              },
            ),
          ),
          Expanded(child: corps),
        ],
      ),
    );
  }
}

/// La pile de chaque membre, sur deux colonnes.
class _Piles extends StatelessWidget {
  const _Piles({required this.membres});

  final List<LifestyleDeMembre> membres;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var c = 0; c < 2; c++) ...[
        if (c > 0) const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              for (var i = c; i < membres.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Appuyable(
                    semantique: '${membres[i].nom}, ${nombrePublications(membres[i].nombre)}',
                    onTap: () => context.push(ici(context, 'lifestyle/${membres[i].pseudo}')),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(aspectRatio: 0.8, child: membres[i].photos.isEmpty ? const PhotoArrondie('') : Pile(photos: membres[i].photos)),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Avatar(nom: membres[i].nom, taille: 22, photo: membres[i].avatar),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                membres[i].nom.isEmpty ? membres[i].pseudo : membres[i].nom,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        Text(nombrePublications(membres[i].nombre), style: TextStyle(fontSize: 12, color: Couleurs.discret)),
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

// ------------------------------------------------------------ le lifestyle d un membre

class EcranLifestyleDe extends StatefulWidget {
  const EcranLifestyleDe({super.key, required this.pseudo});

  final String pseudo;

  @override
  State<EcranLifestyleDe> createState() => _EcranLifestyleDeState();
}

class _EcranLifestyleDeState extends State<EcranLifestyleDe> {
  List<Publication>? _publications;
  bool _introuvable = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final p = await Lifestyle.instance.deMembre(widget.pseudo);
    if (!mounted) return;
    setState(() {
      _publications = p;
      _introuvable = p == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final p = _publications;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          _EnTete(titre: t('Lifestyle de {nom}', {'nom': '@${widget.pseudo}'})),
          if (_introuvable)
            EtatVide(icone: 'cadenas', titre: t('Lifestyle indisponible'), texte: t('Ce lifestyle n’est pas visible, ou la connexion a été perdue.'), action: t('Réessayer'), onAction: _charger)
          else if (p == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: LogoQuiTourne(taille: 30)),
            )
          else if (p.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(t('Rien encore.'), style: Textes.discret, textAlign: TextAlign.center),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: marge),
              child: MosaiquePublications(publications: p, titre: (_) => '', onTap: (i) => context.push(ici(context, 'lieu/_/photo/${p[i].id}'))),
            ),
        ],
      ),
    );
  }
}
