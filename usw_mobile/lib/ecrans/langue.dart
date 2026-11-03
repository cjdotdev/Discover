// La langue de Discover (Reglages, Affichage, Langue) : celle du telephone par
// defaut, le francais et l anglais dans l application, puis les langues du
// serveur (les africaines d abord), qui se telechargent d un toucher et se
// retirent d un appui long. Hors ligne : les langues deja la restent.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/feuille.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/verre.dart';

class EcranLangue extends StatefulWidget {
  const EcranLangue({super.key});

  @override
  State<EcranLangue> createState() => _EcranLangueState();
}

class _EcranLangueState extends State<EcranLangue> {
  final _langue = Langue.instance;

  /// Les langues du serveur (nul : pas encore arrivees, ou hors ligne).
  List<PaquetLangue>? _serveur;
  bool _charge = true;

  /// La langue en cours de telechargement.
  String? _enCours;

  @override
  void initState() {
    super.initState();
    _langue.addListener(_maj);
    _charger();
  }

  @override
  void dispose() {
    _langue.removeListener(_maj);
    super.dispose();
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  Future<void> _charger() async {
    setState(() => _charge = true);
    final l = await _langue.disponibles();
    if (!mounted) return;
    setState(() {
      _serveur = l ?? _serveur;
      _charge = false;
    });
  }

  Future<void> _choisir(String code) async {
    HapticFeedback.selectionClick();
    await _langue.choisir(code);
  }

  // Une langue pas encore la : elle se telecharge, puis devient la langue de Discover.
  Future<void> _telecharger(PaquetLangue p) async {
    if (_enCours != null) return;
    setState(() => _enCours = p.code);
    final ok = await _langue.telecharger(p);
    if (!mounted) return;
    setState(() => _enCours = null);
    if (!ok) return bulle(context, t('Impossible de télécharger cette langue. Vérifiez votre connexion, puis réessayez.'), icone: 'alerte');
    await _choisir(p.code);
  }

  Future<void> _retirer(String code, String nom) async {
    HapticFeedback.mediumImpact();
    final oui = await confirmer(
      context,
      titre: t('Supprimer {langue} ?', {'langue': nom}),
      texte: t('Cette langue sera supprimée de ce téléphone. Vous pourrez la télécharger de nouveau à tout moment.'),
      action: t('Supprimer'),
      icone: 'poubelle',
    );
    if (!oui) return;
    await _langue.retirer(code);
    if (mounted) bulle(context, t('{langue} a été supprimée de ce téléphone.', {'langue': nom}), icone: 'poubelle');
  }

  /// Le nom de la langue du telephone, dans cette langue (nul : inconnu ici).
  String? get _nomDuTelephone {
    final c = Langue.langueDuTelephone;
    return Langue.incluses[c] ?? _langue.telechargees[c]?.nom ?? _serveur?.where((p) => p.code == c).firstOrNull?.nom;
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final choix = _langue.choix;
    final nomTel = _nomDuTelephone;
    final serveur = [
      for (final p in _serveur ?? const <PaquetLangue>[])
        if (!Langue.incluses.containsKey(p.code)) p,
    ];
    // Les langues telechargees que le serveur ne propose plus (ou hors ligne) restent choisissables.
    final connues = {for (final p in serveur) p.code};
    final seules = [
      for (final e in _langue.telechargees.entries)
        if (!connues.contains(e.key) && !Langue.incluses.containsKey(e.key)) (code: e.key, nom: e.value.nom),
    ]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    final africaines = serveur.where((p) => p.africaine).toList();
    final autres = serveur.where((p) => !p.africaine).toList();
    final horsLigne = !_charge && _serveur == null;

    _LigneLangue serveurLigne(PaquetLangue p) {
      final telechargee = _langue.telechargees.containsKey(p.code);
      return _LigneLangue(
        nom: p.nom,
        sousTitre: p.nomFr.isEmpty || p.nomFr == p.nom ? null : p.nomFr,
        aRelire: p.aRelire,
        choisie: choix == p.code,
        enCours: _enCours == p.code,
        taille: telechargee ? null : p.tailleKo,
        onTap: telechargee ? () => _choisir(p.code) : () => _telecharger(p),
        onLongPress: telechargee ? () => _retirer(p.code, p.nom) : null,
      );
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              Expanded(
                child: Text(
                  t('Langue'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 22),
          _Groupe(
            lignes: [
              _LigneLangue(nom: nomTel == null ? t('Langue du téléphone') : t('Langue du téléphone ({langue})', {'langue': nomTel}), choisie: choix == 'systeme', onTap: () => _choisir('systeme')),
              for (final e in Langue.incluses.entries) _LigneLangue(nom: e.value, choisie: choix == e.key, onTap: () => _choisir(e.key)),
            ],
          ),
          if (_charge && _serveur == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: LogoQuiTourne(taille: 30)),
            ),
          if (horsLigne) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(t('Aucune connexion. Les autres langues s’afficheront lorsque vous serez de nouveau en ligne.'), style: Textes.petit),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: BoutonVerre(texte: t('Réessayer'), icone: 'retourner', large: false, onTap: _charger),
            ),
            const SizedBox(height: 18),
          ],
          if (africaines.isNotEmpty) _Groupe(titre: t('Langues africaines'), lignes: [for (final p in africaines) serveurLigne(p)]),
          if (autres.isNotEmpty) _Groupe(titre: t('Autres langues'), lignes: [for (final p in autres) serveurLigne(p)]),
          if (seules.isNotEmpty)
            _Groupe(
              titre: t('Langues téléchargées'),
              lignes: [for (final l in seules) _LigneLangue(nom: l.nom, choisie: choix == l.code, onTap: () => _choisir(l.code), onLongPress: () => _retirer(l.code, l.nom))],
            ),
          if (_langue.telechargees.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Text(t('Pour supprimer une langue téléchargée, appuyez de manière prolongée sur son nom.'), style: Textes.petit),
            ),
        ],
      ),
    );
  }
}

/// Un groupe de lignes sur une plaque de verre, son titre au-dessus (comme les reglages).
class _Groupe extends StatelessWidget {
  const _Groupe({this.titre, required this.lignes});

  final String? titre;
  final List<_LigneLangue> lignes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titre != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                titre!,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
              ),
            ),
          ),
        Plaque(
          child: Column(
            children: [
              for (var i = 0; i < lignes.length; i++) ...[if (i > 0) Divider(height: 1, thickness: 0.7, indent: 16, color: Couleurs.filet), lignes[i]],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Une langue : son nom dans la langue meme, en dessous son nom en francais ; a droite la
/// coche (choisie), l attente (telechargement) ou le bouton Telecharger.
class _LigneLangue extends StatelessWidget {
  const _LigneLangue({required this.nom, required this.choisie, required this.onTap, this.sousTitre, this.aRelire = false, this.enCours = false, this.taille, this.onLongPress});

  final String nom;
  final String? sousTitre;
  final bool aRelire;
  final bool choisie;
  final bool enCours;

  /// La taille du paquet en Ko : non nulle, la langue est a telecharger.
  final int? taille;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final aTelecharger = taille != null;
    final Widget droite;
    if (enCours) {
      droite = Semantics(label: t('Téléchargement…'), child: const LogoQuiTourne(taille: 22));
    } else if (aTelecharger) {
      droite = BoutonVerre(texte: taille! > 0 ? t('Télécharger ({taille} Ko)', {'taille': taille}) : t('Télécharger'), icone: 'telecharger', large: false, onTap: onTap);
    } else {
      droite = AnimatedOpacity(
        opacity: choisie ? 1 : 0,
        duration: Durees.interface,
        child: Icone('coche', taille: 22, couleur: Couleurs.ocean),
      );
    }
    return Semantics(
      selected: choisie,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: enCours ? null : onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Mesures.hautLigne),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nom,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: Couleurs.texte),
                      ),
                      if (sousTitre != null) Text(sousTitre!, style: TextStyle(fontSize: 13.5, color: Couleurs.discret)),
                      if (aRelire) Text(t('Traduction à relire'), style: TextStyle(fontSize: 12, color: Couleurs.discret)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                droite,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
