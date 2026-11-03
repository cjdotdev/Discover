// « Gérer Discover » : l application de l equipe, cachee dans Discover. Un
// appui long sur le logo de l accueil ; le serveur dit si ce compte est de
// l equipe (ADMIN_EMAILS, sinon rien ne se passe, aucun signe) ; puis
// l empreinte du telephone. Trois onglets : le tableau de bord, les membres,
// la moderation. Quitter Discover referme tout : il faudra l empreinte encore.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../donnees/equipe.dart';
import '../../donnees/moderation.dart';
import '../../outils/langue.dart';
import '../../theme/jetons.dart';
import '../../theme/theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/courbe.dart';
import '../../widgets/icone.dart';
import '../../widgets/page.dart';
import '../../widgets/verre.dart';
import 'membres.dart';

/// L appui long sur le logo : la porte. Pour un compte qui n est pas de
/// l equipe, rien ne se passe.
Future<void> ouvrirGerer(BuildContext context) async {
  if (!await Equipe.instance.reconnue()) return;
  HapticFeedback.heavyImpact();
  if (!context.mounted || !await _empreinte(context)) return;
  if (context.mounted) context.push('/gerer');
}

Future<bool> _empreinte(BuildContext context) async {
  final auth = LocalAuthentication();
  try {
    if (!await auth.canCheckBiometrics || (await auth.getAvailableBiometrics()).isEmpty) {
      if (context.mounted) bulle(context, t('Pour ouvrir l’administration, ajoutez une empreinte digitale dans les paramètres du téléphone.'), icone: 'cadenas');
      return false;
    }
    return await auth.authenticate(localizedReason: t('Gérer Discover'), biometricOnly: true);
  } catch (_) {
    return false;
  }
}

// ------------------------------------------------------------------ la coquille

class EcranGerer extends StatefulWidget {
  const EcranGerer({super.key});

  @override
  State<EcranGerer> createState() => _EcranGererState();
}

class _EcranGererState extends State<EcranGerer> {
  int _onglet = 0;

  // Discover quitte l ecran (un autre appli, l ecran eteint) : l administration se referme.
  late final _cycle = AppLifecycleListener(
    onHide: () {
      if (mounted) context.go('/accueil');
    },
  );

  @override
  void initState() {
    super.initState();
    _cycle;
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final bas = MediaQuery.paddingOf(context).bottom;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final noms = [(t('Tableau de bord'), 'grille'), (t('Membres'), 'profil'), (t('Modération'), 'bouclier')];
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 6),
            child: Row(
              children: [
                RondVerre(icone: 'fermer', semantique: t('Fermer l’administration'), onTap: () => context.go('/accueil')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('Gérer Discover'), style: Textes.sousTitre),
                      Text(noms[_onglet].$1, style: Textes.petit),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _onglet,
              children: [
                _OngletTableau(versModeration: () => setState(() => _onglet = 2)),
                const OngletMembres(),
                const _OngletModeration(),
              ],
            ),
          ),
          // Les onglets de l administration : l icone, son nom dessous ; le choisi a l encre.
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 4, marge, bas + 6),
            child: Row(
              children: [
                for (var i = 0; i < noms.length; i++)
                  Expanded(
                    child: Appuyable(
                      semantique: noms[i].$1,
                      onTap: () => setState(() => _onglet = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icone(noms[i].$2, taille: 24, couleur: _onglet == i ? Couleurs.texte : Couleurs.discret),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                noms[i].$1,
                                style: TextStyle(fontSize: 12, fontWeight: _onglet == i ? FontWeight.w700 : FontWeight.w500, color: _onglet == i ? Couleurs.texte : Couleurs.discret),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ des briques

/// Un titre de section.
class TitreSection extends StatelessWidget {
  const TitreSection(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      texte,
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Couleurs.texte),
    ),
  );
}

/// Un chiffre en tuile : sa valeur en grand, son nom dessous ; une evolution si elle est connue.
class Tuile extends StatelessWidget {
  const Tuile({super.key, required this.nom, required this.valeur, this.evolution, this.point = false, this.onTap});

  final String nom;
  final int valeur;
  final Evolution? evolution;

  /// Un point devant le nom (en ligne).
  final bool point;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = evolution;
    String? ecart;
    var monte = true;
    if (e != null) {
      if (e.precedente == 0) {
        ecart = e.periode == 0 ? t('stable') : t('nouveau');
      } else {
        final pct = ((e.periode - e.precedente) * 100 / e.precedente).round();
        monte = pct >= 0;
        ecart = pct == 0 ? t('stable') : '${pct > 0 ? '+' : ''}$pct %';
      }
    }
    final contenu = Plaque(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombreLisible(valeur),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: Couleurs.texte, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (point) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: Couleurs.succes, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Couleurs.discret),
                ),
              ),
            ],
          ),
          if (ecart != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (ecart.endsWith('%'))
                  Transform.rotate(
                    angle: monte ? 0 : 3.1416,
                    child: Icone('fleche-haut', taille: 13, couleur: Couleurs.texte),
                  ),
                if (ecart.endsWith('%')) const SizedBox(width: 3),
                Text(
                  ecart,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Couleurs.texte),
                ),
                Flexible(
                  child: Text(
                    ' ${t('vs période précédente')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Couleurs.discret),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    final lu = t('{nom} : {valeur}', {'nom': nom, 'valeur': valeur});
    return onTap == null ? Semantics(label: lu, child: contenu) : Appuyable(semantique: lu, onTap: onTap, child: contenu);
  }
}

/// Des tuiles, deux par ligne (trois sur une tablette).
class GrilleTuiles extends StatelessWidget {
  const GrilleTuiles({super.key, required this.tuiles});

  final List<Widget> tuiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final colonnes = c.maxWidth >= 560 ? 3 : 2;
      final largeur = (c.maxWidth - 10 * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final tuile in tuiles) SizedBox(width: largeur, child: tuile)],
      );
    },
  );
}

// ------------------------------------------------------------------ le tableau de bord

class _OngletTableau extends StatefulWidget {
  const _OngletTableau({required this.versModeration});

  final VoidCallback versModeration;

  @override
  State<_OngletTableau> createState() => _OngletTableauState();
}

class _OngletTableauState extends State<_OngletTableau> {
  int _jours = 30;
  Tableau? _tableau;
  bool _echec = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final tableau = await Equipe.instance.tableau(jours: _jours);
    if (!mounted) return;
    setState(() {
      _echec = tableau == null;
      _tableau = tableau ?? _tableau;
    });
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final tab = _tableau;
    if (tab == null) {
      return Center(
        child: _echec ? BoutonVerre(texte: t('Réessayer'), large: false, onTap: _charger) : const LogoQuiTourne(taille: 34),
      );
    }
    final m = tab.maintenant;
    final p = tab.periode;
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: EdgeInsets.fromLTRB(marge, 8, marge, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final j in const [7, 30, 90])
                Pastille(
                  texte: t('{n} derniers jours', {'n': j}),
                  retenue: _jours == j,
                  onTap: () {
                    setState(() => _jours = j);
                    _charger();
                  },
                ),
            ],
          ),
          TitreSection(t('En ce moment')),
          GrilleTuiles(
            tuiles: [
              Tuile(nom: t('En ligne'), valeur: m['en_ligne'] ?? 0, point: true),
              Tuile(nom: t('Actifs aujourd’hui'), valeur: m['aujourdhui'] ?? 0),
              Tuile(nom: t('Actifs sur 7 jours'), valeur: m['semaine'] ?? 0),
              Tuile(nom: t('Actifs sur 30 jours'), valeur: m['mois'] ?? 0),
              Tuile(nom: t('Membres'), valeur: m['membres'] ?? 0),
              Tuile(nom: t('Comptes suspendus'), valeur: m['suspendus'] ?? 0),
              Tuile(nom: t('Photos en ligne'), valeur: m['publications'] ?? 0),
              Tuile(nom: t('Reels en ligne'), valeur: m['reels'] ?? 0),
            ],
          ),
          TitreSection(t('À traiter')),
          GrilleTuiles(
            tuiles: [
              Tuile(nom: t('Publications à vérifier'), valeur: m['a_verifier'] ?? 0, onTap: widget.versModeration),
              Tuile(nom: t('Signalements ouverts'), valeur: m['signalements'] ?? 0, onTap: widget.versModeration),
            ],
          ),
          TitreSection(t('Sur les {n} derniers jours', {'n': _jours})),
          GrilleTuiles(
            tuiles: [
              for (final (cle, nom) in [
                ('inscriptions', t('Inscriptions')),
                ('publications', t('Publications')),
                ('reactions', t('Réactions')),
                ('commentaires', t('Commentaires')),
                ('signalements', t('Signalements')),
              ])
                if (p[cle] case final e?) Tuile(nom: nom, valeur: e.periode, evolution: e),
            ],
          ),
          TitreSection(t('Évolution par jour')),
          for (final (cle, nom) in [
            ('actifs', t('Membres actifs')),
            ('inscriptions', t('Inscriptions')),
            ('publications', t('Publications')),
            ('reactions', t('Réactions')),
            ('commentaires', t('Commentaires')),
          ])
            if (tab.courbes[cle] case final v?)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Plaque(
                  padding: const EdgeInsets.all(16),
                  child: Courbe(
                    titre: nom,
                    valeurs: v,
                    dates: tab.dates,
                    // Les actifs : la moyenne par jour ; le reste : le total.
                    resume: cle == 'actifs' ? t('{n} / jour', {'n': (v.fold<int>(0, (a, b) => a + b) / (v.isEmpty ? 1 : v.length)).toStringAsFixed(1).replaceAll('.', ',')}) : null,
                  ),
                ),
              ),
          if (tab.lieux.isNotEmpty) ...[
            TitreSection(t('Lieux les plus photographiés')),
            Plaque(
              padding: const EdgeInsets.all(16),
              child: Classement(lignes: [for (final l in tab.lieux) (l.nom, l.n)]),
            ),
          ],
          if (tab.createurs.isNotEmpty) ...[
            TitreSection(t('Créateurs les plus aimés')),
            Plaque(
              padding: const EdgeInsets.all(16),
              child: Classement(lignes: [for (final c in tab.createurs) ('@${c.pseudo}', c.n)], onTap: (i) => context.push('/gerer/membre/${tab.createurs[i].pseudo}')),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ la moderation

class _OngletModeration extends StatefulWidget {
  const _OngletModeration();

  @override
  State<_OngletModeration> createState() => _OngletModerationState();
}

class _OngletModerationState extends State<_OngletModeration> {
  List<MembreSignale>? _membres;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    await Moderation.instance.file();
    final m = await Equipe.instance.membresSignales();
    if (mounted) setState(() => _membres = m ?? _membres);
  }

  Future<void> _classer(MembreSignale s) async {
    if (!await Equipe.instance.classerMembre(s.membre.pseudo)) {
      if (mounted) bulle(context, t('Impossible de classer les signalements. Réessayez.'), icone: 'alerte');
      return;
    }
    if (!mounted) return;
    bulle(context, t('Les signalements de @{pseudo} ont été classés.', {'pseudo': s.membre.pseudo}), icone: 'coche');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final totaux = Moderation.instance.totaux;
    final membres = _membres;
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: EdgeInsets.fromLTRB(marge, 8, marge, 24),
        children: [
          GrilleTuiles(
            tuiles: [
              Tuile(nom: t('Publications à vérifier'), valeur: totaux['a_verifier'] ?? 0, onTap: () => context.push('/moderation?file=0').then((_) => _charger())),
              Tuile(nom: t('Publications et commentaires signalés'), valeur: Moderation.instance.signalesEnTout, onTap: () => context.push('/moderation?file=1').then((_) => _charger())),
            ],
          ),
          TitreSection(t('Membres signalés')),
          if (membres == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: LogoQuiTourne(taille: 34)),
            )
          else if (membres.isEmpty)
            Plaque(
              padding: const EdgeInsets.all(16),
              child: Text(t('Aucun membre signalé pour l’instant.'), style: Textes.discret),
            )
          else
            for (final s in membres)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Plaque(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(nom: s.membre.nom, taille: 40, photo: s.membre.avatar),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.membre.nom, style: Textes.libelle),
                                Text('@${s.membre.pseudo} · ${tn(s.signalements, '{n} signalement', '{n} signalements')}', style: Textes.petit),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final e in s.motifs.entries) Text('${e.value} × ${t(e.key)}', style: Textes.petit),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: BoutonVerre(texte: t('Voir la fiche'), onTap: () => context.push('/gerer/membre/${s.membre.pseudo}').then((_) => _charger())),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BoutonVerre(texte: t('Classer'), onTap: () => _classer(s)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
