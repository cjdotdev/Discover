// « Gérer Discover », les membres : la recherche (nom, @pseudo, e-mail,
// ville, sans accents), les filtres (en ligne, actifs, nouveaux, signales,
// suspendus, inactifs), le tri ; puis la fiche d un membre, tout son
// parcours, et ce que l equipe peut faire : lui ecrire, le suspendre.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../donnees/catalogue.dart';
import '../../donnees/communaute.dart';
import '../../donnees/equipe.dart';
import '../../outils/chemins.dart';
import '../../outils/langue.dart';
import '../../theme/jetons.dart';
import '../../theme/theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/champ.dart';
import '../../widgets/courbe.dart';
import '../../widgets/feuille.dart';
import '../../widgets/feuilles.dart';
import '../../widgets/icone.dart';
import '../../widgets/mosaique.dart';
import '../../widgets/mouvement.dart';
import '../../widgets/page.dart';
import '../../widgets/verre.dart';
import 'gerer.dart';

// Les filtres et les tris : la cle envoyee au serveur, et son nom a l ecran.
List<(String, String)> get _filtres => [
  ('tous', t('Tous')),
  ('en_ligne', t('En ligne')),
  ('aujourdhui', t('Aujourd’hui')),
  ('semaine', t('7 jours')),
  ('mois', t('30 jours')),
  ('nouveaux', t('Nouveaux')),
  ('signales', t('Signalés')),
  ('suspendus', t('Suspendus')),
  ('inactifs', t('Inactifs')),
];

List<(String, String)> get _tris => [
  ('recents', t('Les plus récents')),
  ('actifs', t('Les plus actifs')),
  ('publications', t('Le plus de publications')),
  ('signalements', t('Les plus signalés')),
  ('nom', t('Par nom d’utilisateur')),
];

class OngletMembres extends StatefulWidget {
  const OngletMembres({super.key});

  @override
  State<OngletMembres> createState() => _OngletMembresState();
}

class _OngletMembresState extends State<OngletMembres> {
  final _champ = TextEditingController();
  Timer? _attente;
  String _filtre = 'tous';
  String _tri = 'recents';
  final _membres = <MembreEquipe>[];
  int _total = 0;
  int _page = 0;
  int _dernierePage = 1;
  bool _charge = false;
  bool _echec = false;

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    _champ.dispose();
    super.dispose();
  }

  Future<void> _recharger() async {
    _page = 0;
    _dernierePage = 1;
    _membres.clear();
    await _suite();
  }

  // La page suivante, quand la liste arrive en bas.
  Future<void> _suite() async {
    if (_charge || _page >= _dernierePage) return;
    setState(() => _charge = true);
    final demande = (_champ.text, _filtre, _tri);
    final r = await Equipe.instance.membres(q: demande.$1, filtre: demande.$2, tri: demande.$3, page: _page + 1);
    if (!mounted) return;
    // Une recherche plus recente est partie entre-temps : celle-ci ne compte plus.
    if (demande != (_champ.text, _filtre, _tri)) {
      setState(() => _charge = false);
      return;
    }
    setState(() {
      _charge = false;
      _echec = r == null;
      if (r != null) {
        _membres.addAll(r.membres);
        _total = r.total;
        _page = r.page;
        _dernierePage = r.dernierePage;
      }
    });
  }

  void _chercher(String _) {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 350), _recharger);
  }

  Future<void> _choisirTri() => montrerFeuille<void>(
    context,
    titre: t('Trier les membres'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ListeMotifs(
        motifs: [for (final tri in _tris) (tri.$2, null)],
        choisi: _tris.indexWhere((tri) => tri.$1 == _tri),
        onChoisi: (i) {
          Navigator.pop(f);
          setState(() => _tri = _tris[i].$1);
          _recharger();
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(marge, 8, marge, 0),
          child: Row(
            children: [
              Expanded(
                child: ChampVerre(icone: 'loupe', indice: t('Rechercher par nom, @pseudo, e-mail ou ville'), controleur: _champ, onChanged: _chercher, action: TextInputAction.search),
              ),
              const SizedBox(width: 8),
              RondVerre(icone: 'filtres', semantique: t('Trier'), onTap: _choisirTri),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: marge),
            children: [
              for (final (cle, nom) in _filtres) ...[
                Pastille(
                  texte: nom,
                  retenue: _filtre == cle,
                  onTap: () {
                    setState(() => _filtre = cle);
                    _recharger();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(marge + 4, 10, marge, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_total > 1 ? t('{n} membres', {'n': nombreLisible(_total)}) : t('{n} membre', {'n': nombreLisible(_total)})} · ${_tris.firstWhere((tri) => tri.$1 == _tri).$2.toLowerCase()}',
              style: Textes.petit,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _recharger,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 400) _suite();
                return false;
              },
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(marge, 4, marge, 24),
                itemCount: _membres.length + 1,
                itemBuilder: (context, i) {
                  if (i == _membres.length) {
                    if (_charge) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: LogoQuiTourne(taille: 34)),
                      );
                    }
                    if (_echec) {
                      return Center(
                        child: BoutonVerre(texte: t('Réessayer'), large: false, onTap: _suite),
                      );
                    }
                    return _membres.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(t('Aucun membre trouvé.'), style: Textes.discret, textAlign: TextAlign.center),
                          )
                        : const SizedBox.shrink();
                  }
                  final m = _membres[i];
                  return _LigneMembre(membre: m, onTap: () => context.push('/gerer/membre/${m.pseudo}').then((_) => _recharger()));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Une ligne : la photo (un point s il est en ligne), le nom, ses marques, sa derniere venue.
class _LigneMembre extends StatelessWidget {
  const _LigneMembre({required this.membre, required this.onTap});

  final MembreEquipe membre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = membre;
    final venue = m.enLigne ? t('En ligne') : (m.derniereActivite == null ? t('Aucune activité') : _depuis(m.derniereActivite!));
    return Appuyable(
      semantique: '${m.nom}, @${m.pseudo}, $venue',
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(nom: m.nom, taille: 46, photo: m.avatar),
                if (m.enLigne)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Couleurs.succes,
                        shape: BoxShape.circle,
                        border: Border.all(color: Couleurs.fond, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(m.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Textes.libelle),
                      ),
                      if (m.suspendu) ...[const SizedBox(width: 6), _Marque(t('Suspendu'), danger: true)],
                      if (m.equipe) ...[const SizedBox(width: 6), _Marque(t('Équipe'))],
                    ],
                  ),
                  Text('@${m.pseudo}${m.ville.isEmpty ? '' : ' · ${m.ville}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Textes.petit),
                  Text(
                    '${tn(m.publications, '{n} publication', '{n} publications')}${m.signalements > 0 ? ' · ${tn(m.signalements, '{n} signalement', '{n} signalements')}' : ''}',
                    style: Textes.petit,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(venue, style: TextStyle(fontSize: 12, color: m.enLigne ? Couleurs.texte : Couleurs.discret)),
          ],
        ),
      ),
    );
  }
}

/// Une petite marque a cote d un nom.
class _Marque extends StatelessWidget {
  const _Marque(this.texte, {this.danger = false});

  final String texte;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: (danger ? Couleurs.erreur : Couleurs.texte).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(
      texte,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: danger ? Couleurs.erreur : Couleurs.texte),
    ),
  );
}

/// « il y a 3 h », « a l instant ».
String _depuis(DateTime d) => DateTime.now().difference(d).inMinutes < 1 ? t('à l’instant') : t('il y a {duree}', {'duree': ilYA(d)});

// ------------------------------------------------------------------ la fiche

/// Le ton d un message : la cle envoyee au serveur, et son nom a l ecran.
List<(String, String)> get _tons => [('felicitations', t('Félicitations')), ('info', t('Information')), ('avertissement', t('Avertissement'))];

/// Les motifs de suspension, tels qu ils partent au serveur.
const _motifsSuspension = ['Spam ou arnaque', 'Images générées par IA, à répétition', 'Contenus choquants ou violents', 'Harcèlement ou propos haineux', 'Faux compte ou usurpation'];

/// Les memes, a l ecran, dans la langue choisie.
List<Motif> get _motifsSuspensionAffiches => [
  (t('Spam ou arnaque'), null),
  (t('Images générées par IA, à répétition'), null),
  (t('Contenus choquants ou violents'), null),
  (t('Harcèlement ou propos haineux'), null),
  (t('Faux compte ou usurpation'), null),
];

class EcranFicheMembre extends StatefulWidget {
  const EcranFicheMembre({super.key, required this.pseudo});

  final String pseudo;

  @override
  State<EcranFicheMembre> createState() => _EcranFicheMembreState();
}

class _EcranFicheMembreState extends State<EcranFicheMembre> {
  FicheMembre? _f;
  bool _echec = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final f = await Equipe.instance.fiche(widget.pseudo);
    if (!mounted) return;
    setState(() {
      _echec = f == null;
      _f = f ?? _f;
    });
  }

  Future<void> _ecrire(MembreEquipe m) async {
    final champ = TextEditingController();
    var ton = 0;
    await montrerFeuille<void>(
      context,
      titre: t('Écrire à @{pseudo}', {'pseudo': m.pseudo}),
      contenu: (f) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: StatefulBuilder(
          builder: (context, maj) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (var i = 0; i < _tons.length; i++) Pastille(texte: _tons[i].$2, retenue: ton == i, onTap: () => maj(() => ton = i))],
              ),
              const SizedBox(height: 12),
              ChampVerre(icone: 'commentaire', indice: t('Votre message, signé « L’équipe de Discover »'), controleur: champ, lignes: 4, autofocus: true, onChanged: (_) => maj(() {})),
              const SizedBox(height: 14),
              BoutonVerre(
                texte: t('Envoyer'),
                icone: 'envoyer',
                plein: true,
                onTap: champ.text.trim().length < 3
                    ? null
                    : () async {
                        Navigator.pop(f);
                        final (ok, message) = await Equipe.instance.message(m.pseudo, ton: _tons[ton].$1, texte: champ.text.trim());
                        if (!mounted) return;
                        bulle(context, message, icone: ok ? 'envoyer' : 'alerte');
                        if (ok) _charger();
                      },
              ),
            ],
          ),
        ),
      ),
    );
    champ.dispose();
  }

  Future<void> _suspendre(MembreEquipe m) async {
    int? choisi;
    final precision = TextEditingController();
    final motif = await montrerFeuille<String>(
      context,
      titre: t('Suspendre @{pseudo}', {'pseudo': m.pseudo}),
      contenu: (f) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: StatefulBuilder(
          builder: (context, maj) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('Ce membre ne pourra plus se connecter, et ses publications seront masquées jusqu’à la réactivation du compte.'), style: Textes.petit),
              const SizedBox(height: 10),
              ListeMotifs(motifs: _motifsSuspensionAffiches, choisi: choisi, onChoisi: (i) => maj(() => choisi = i)),
              const SizedBox(height: 8),
              ChampVerre(icone: 'texte', indice: t('Détails (facultatif)'), controleur: precision, lignes: 2),
              const SizedBox(height: 14),
              BoutonVerre(
                texte: t('Suspendre'),
                teinte: TeinteVerre.rouge,
                onTap: choisi == null ? null : () => Navigator.pop(f, [_motifsSuspension[choisi!], precision.text.trim()].where((x) => x.isNotEmpty).join(' : ')),
              ),
            ],
          ),
        ),
      ),
    );
    precision.dispose();
    if (motif == null || !mounted) return;
    final (membre, message) = await Equipe.instance.suspendre(m.pseudo, motif: motif);
    if (!mounted) return;
    bulle(context, message, icone: membre == null ? 'alerte' : 'bloque');
    if (membre != null) _charger();
  }

  Future<void> _reactiver(MembreEquipe m) async {
    final oui = await confirmer(
      context,
      titre: t('Réactiver @{pseudo} ?', {'pseudo': m.pseudo}),
      texte: t('Ce membre pourra de nouveau se connecter, et ses publications seront à nouveau visibles.'),
      action: t('Réactiver'),
      icone: 'coche',
      danger: false,
    );
    if (!oui || !mounted) return;
    final (membre, message) = await Equipe.instance.suspendre(m.pseudo);
    if (!mounted) return;
    bulle(context, message, icone: membre == null ? 'alerte' : 'coche');
    if (membre != null) _charger();
  }

  String _date(DateTime? d) => d == null ? '—' : '${jourCourt(d)} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final f = _f;
    return Scaffold(
      body: f == null
          ? Center(
              child: _echec ? BoutonVerre(texte: t('Réessayer'), large: false, onTap: _charger) : const LogoQuiTourne(taille: 34),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 32), children: _contenu(f)),
            ),
    );
  }

  List<Widget> _contenu(FicheMembre f) {
    final m = f.membre;
    final c = f.compteurs;
    final publications = Catalogue.instance.publicationsDepuis(f.contenus);
    String statut(String? s) => switch (s) {
      'publie' => t('En ligne'),
      'file_humaine' => t('À vérifier'),
      'refuse' => t('Refusée'),
      'analyse' => t('En analyse'),
      'a_completer' => t('À compléter'),
      _ => t('Brouillon'),
    };
    return [
      Row(
        children: [
          RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
          const Spacer(),
          RondVerre(icone: 'profil', semantique: t('Voir le profil public'), onTap: () => context.push(ici(context, 'createur/${m.pseudo}'))),
        ],
      ),
      const SizedBox(height: 10),
      Center(
        child: AvatarAgrandissable(nom: m.nom, photo: m.avatar, taille: 88),
      ),
      const SizedBox(height: 10),
      Monte(
        child: Text(
          m.nom,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Couleurs.texte),
        ),
      ),
      Text('@${m.pseudo} · ${m.email}', textAlign: TextAlign.center, style: Textes.petit),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          if (m.enLigne) _Marque(t('En ligne')),
          if (m.suspendu) _Marque(t('Suspendu'), danger: true),
          if (m.equipe) _Marque(t('Équipe')),
          if (!m.profilComplete) _Marque(t('Profil incomplet')),
          if (m.suppressionDemandee) _Marque(t('Suppression demandée'), danger: true),
          _Marque(m.fournisseur == 'google' ? 'Google' : t('E-mail')),
        ],
      ),
      if (m.bio.isNotEmpty) ...[const SizedBox(height: 10), Text(m.bio, textAlign: TextAlign.center, style: Textes.corps)],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: BoutonVerre(texte: t('Écrire'), icone: 'envoyer', onTap: () => _ecrire(m)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: m.suspendu
                ? BoutonVerre(texte: t('Réactiver'), icone: 'coche', onTap: () => _reactiver(m))
                : BoutonVerre(texte: t('Suspendre'), icone: 'bloque', teinte: TeinteVerre.rouge, onTap: m.equipe ? null : () => _suspendre(m)),
          ),
        ],
      ),
      if (m.suspendu) ...[
        const SizedBox(height: 12),
        Plaque(
          padding: const EdgeInsets.all(16),
          child: Text(
            m.motifSuspension == null
                ? t('Suspendu le {date}. Aucun motif indiqué.', {'date': _date(m.suspenduLe)})
                : t('Suspendu le {date}. Motif : {motif}', {'date': _date(m.suspenduLe), 'motif': m.motifSuspension}),
            style: TextStyle(fontSize: 14, color: Couleurs.erreur),
          ),
        ),
      ],
      TitreSection(t('Parcours')),
      Plaque(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Ligne(t('Inscription'), _date(m.inscritLe)),
            _Ligne(t('Dernière activité'), m.enLigne ? t('En ligne') : (m.derniereActivite == null ? t('Jamais') : _depuis(m.derniereActivite!))),
            _Ligne(t('Ville'), m.ville.isEmpty ? '—' : m.ville),
            _Ligne(t('Actif ces 30 derniers jours'), tn(c['jours_actifs'] ?? 0, '{n} jour', '{n} jours')),
            const SizedBox(height: 10),
            BandeJours(actif: f.actif, dates: f.dates),
          ],
        ),
      ),
      TitreSection(t('Statistiques')),
      GrilleTuiles(
        tuiles: [
          Tuile(nom: t('Photos en ligne'), valeur: c['publications'] ?? 0),
          Tuile(nom: t('Reels en ligne'), valeur: c['reels'] ?? 0),
          Tuile(nom: t('Réactions reçues'), valeur: c['reactions_recues'] ?? 0),
          Tuile(nom: t('Réactions données'), valeur: c['reactions_donnees'] ?? 0),
          Tuile(nom: t('Commentaires écrits'), valeur: c['commentaires'] ?? 0),
          Tuile(nom: t('Abonnés'), valeur: c['abonnes'] ?? 0),
          Tuile(nom: t('Abonnements'), valeur: c['abonnements'] ?? 0),
          Tuile(nom: t('Collections'), valeur: c['collections'] ?? 0),
          Tuile(nom: t('Publications refusées'), valeur: c['refusees'] ?? 0),
          Tuile(nom: t('Signalements reçus'), valeur: c['signalements_recus'] ?? 0),
          Tuile(nom: t('Signalements envoyés'), valeur: c['signalements_faits'] ?? 0),
        ],
      ),
      const SizedBox(height: 10),
      Plaque(
        padding: const EdgeInsets.all(16),
        child: Courbe(titre: t('Réactions reçues sur les 30 derniers jours'), valeurs: f.reactions, dates: f.dates, hauteur: 100),
      ),
      if (publications.isNotEmpty) ...[
        TitreSection(t('Dernières publications')),
        MosaiquePublications(
          publications: publications,
          titre: (i) => statut(f.statuts[publications[i].id]),
          onTap: (i) => context.push(ici(context, 'lieu/${publications[i].lieu ?? '_'}/photo/${publications[i].id}')),
        ),
      ],
      if (f.signalements.isNotEmpty) ...[
        TitreSection(t('Signalements')),
        Plaque(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in f.signalements)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(s.motif), style: Textes.libelle),
                      Text(
                        '${s.cible == 'utilisateur' ? t('Le compte') : t('Une publication')} · ${s.le == null ? '' : _depuis(s.le!)} · ${switch (s.statut) {
                          'ouvert' => t('ouvert'),
                          'classe' => t('classé'),
                          _ => t('traité'),
                        }}',
                        style: Textes.petit,
                      ),
                      if (s.precision?.isNotEmpty == true) Text(s.precision!, style: Textes.petit),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      if (f.messages.isNotEmpty) ...[
        TitreSection(t('Messages de l’équipe')),
        Plaque(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final msg in f.messages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.texte, style: Textes.corps),
                      Text(
                        '${_tons.firstWhere((ton) => ton.$1 == msg.ton, orElse: () => _tons[1]).$2} · ${msg.le == null ? '' : _depuis(msg.le!)} · ${msg.lu ? t('lu') : t('non lu')}',
                        style: Textes.petit,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      if (f.appareils.isNotEmpty) ...[
        TitreSection(t('Appareils connectés')),
        Plaque(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (final a in f.appareils)
                _Ligne(
                  a.nom,
                  a.dernier != null
                      ? t('Vu {quand}', {'quand': _depuis(a.dernier!)})
                      : a.depuis != null
                      ? t('Connecté {quand}', {'quand': _depuis(a.depuis!)})
                      : t('Connecté'),
                  icone: 'telephone',
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

/// Une ligne nom : valeur.
class _Ligne extends StatelessWidget {
  const _Ligne(this.nom, this.valeur, {this.icone});

  final String nom;
  final String valeur;
  final String? icone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        if (icone != null) ...[Icone(icone!, taille: 18, couleur: Couleurs.discret), const SizedBox(width: 8)],
        Expanded(
          child: Text(nom, style: TextStyle(fontSize: 14, color: Couleurs.discret)),
        ),
        Text(
          valeur,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.texte),
        ),
      ],
    ),
  );
}
