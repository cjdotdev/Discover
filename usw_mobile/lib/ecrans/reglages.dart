// E21 Reglages et Modifier le profil. Les reglages sont des groupes de
// verre : compte, donnees mobiles, autorisations, aide.
// Le lot 5 branchera PATCH /api/v1/moi et les preferences.
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../outils/videos.dart';
import '../outils/images_reseau.dart';
import '../outils/langue.dart';
import '../donnees/catalogue.dart';
import '../donnees/communaute.dart';
import '../donnees/affichage.dart';
import '../donnees/capture.dart';
import '../donnees/push.dart';
import '../donnees/session.dart';
import '../outils/api.dart';
import '../outils/photo_profil.dart';
import '../outils/reseau.dart';
import '../outils/sobriete.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/champ.dart';
import '../widgets/choix_pays_ville.dart';
import '../widgets/feuille.dart';
import '../widgets/feuilles.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/verre.dart';
import 'compte/changer_email.dart';
import 'documents.dart';

/// La confirmation de suppression du compte (Reglages, Confidentialite).
Future<void> confirmerSuppressionCompte(BuildContext context) => montrerFeuille<void>(
  context,
  titre: t('Supprimer votre compte ?'),
  contenu: (f) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('Vos photos, vos reels et vos collections seront supprimés dans 30 jours. Pour tout conserver, reconnectez-vous avant cette date.'), style: Textes.discret),
        const SizedBox(height: 18),
        LigneFeuille(
          icone: 'poubelle',
          texte: t('Supprimer mon compte'),
          danger: true,
          onTap: () async {
            Navigator.pop(f);
            String? message;
            try {
              message = await Session.instance.supprimerCompte();
            } on ApiInjoignable {
              if (context.mounted) bulle(context, t('Aucune connexion. Vérifiez le réseau, puis réessayez.'), icone: 'hors-ligne');
              return;
            } on ErreurApi catch (e) {
              if (context.mounted) bulle(context, e.message, icone: 'alerte');
              return;
            }
            if (!context.mounted) return;
            context.go('/entree');
            bulle(context, message ?? t('Votre compte sera supprimé dans 30 jours. Pour tout conserver, reconnectez-vous avant cette date.'), icone: 'poubelle');
          },
        ),
        LigneFeuille(icone: 'fermer', texte: t('Annuler'), onTap: () => Navigator.pop(f)),
      ],
    ),
  ),
);

/// Les preferences de donnees mobiles, gardees le temps de la session.
class EcranReglages extends StatefulWidget {
  const EcranReglages({super.key});

  @override
  State<EcranReglages> createState() => _EcranReglagesState();
}

class _EcranReglagesState extends State<EcranReglages> {
  // La permission de position d Android (nulle tant qu on ne la connait pas).
  bool? _droitPosition;

  // Au retour des reglages d Android, les permissions sont relues.
  late final AppLifecycleListener _cycle;

  @override
  void initState() {
    super.initState();
    _cycle = AppLifecycleListener(onResume: _lireDroits);
    _lireDroits();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  Future<void> _lireDroits() async {
    bool? droit;
    try {
      final d = await Geolocator.checkPermission();
      droit = d == LocationPermission.whileInUse || d == LocationPermission.always;
    } catch (_) {}
    await Push.instance.lirePermission();
    if (mounted) setState(() => _droitPosition = droit);
  }

  // La position : le choix est garde sur le serveur (PATCH moi) ; « Autoriser »
  // demande aussi la permission d Android, qui garde le dernier mot.
  Future<void> _changerPosition(bool v) async {
    final s = Session.instance;
    if (Api.instance.jeton == null) return bulle(context, t('Connectez-vous pour gérer l’accès à votre position.'), icone: 'profil');
    final avant = s.position;
    String? raison;
    if (v && !await demanderLocalisation()) {
      raison = positionManquee == SansPosition.coupee
          ? t('La localisation est désactivée sur ce téléphone. Activez-la, puis réessayez.')
          : t('Android bloque l’accès à la position pour Discover. Autorisez-le dans les réglages d’Android.');
    }
    await _lireDroits();
    if (!mounted) return;
    setState(() => s.position = v);
    try {
      await s.envoyerProfil();
    } on ApiInjoignable {
      if (!mounted) return;
      setState(() => s.position = avant);
      return bulle(context, t('Aucune connexion. Le réglage n’a pas été enregistré.'), icone: 'hors-ligne');
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() => s.position = avant);
      return bulle(context, e.message, icone: 'alerte');
    }
    if (mounted && raison != null) bulle(context, raison, icone: 'cible');
  }

  // Une autorisation : on la donne ou la retire ici ; le systeme garde le
  // dernier mot (ses reglages s ouvrent si elle y est bloquee).
  // Le theme : celui du telephone par defaut, ou toujours clair, ou sombre.
  Future<void> _theme() => montrerFeuille<void>(
    context,
    titre: t('Thème'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: StatefulBuilder(
        builder: (context, maj) => ListeMotifs(
          motifs: [(t('Paramètre par défaut du système'), t('Suit le thème clair ou sombre du téléphone')), (t('Clair'), null), (t('Sombre'), null)],
          choisi: Affichage.instance.mode.index,
          onChoisi: (i) {
            Affichage.instance.choisirTheme(ModeTheme.values[i]);
            maj(() {});
            _fermerFeuille(f);
          },
        ),
      ),
    ),
  );

  // Une feuille de choix se ferme une fois, un instant apres le choix ; deux touches rapides
  // ne ferment pas aussi la page en dessous.
  static void _fermerFeuille(BuildContext f) {
    final route = ModalRoute.of(f);
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (f.mounted && route != null && route.isCurrent) Navigator.pop(f);
    });
  }

  // L allegement du verre : automatique (l economiseur, un petit telephone), toujours, ou jamais.
  Future<void> _allegement() => montrerFeuille<void>(
    context,
    titre: t('Allègement du verre'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: StatefulBuilder(
        builder: (context, maj) => ListeMotifs(
          motifs: [
            (t('Automatique'), t('Allégé quand l’économiseur de batterie est activé ou sur un petit téléphone')),
            (t('Toujours allégé'), t('Moins d’effets de verre, plus d’autonomie')),
            (t('Tout le verre'), t('Même quand l’économiseur de batterie est activé')),
          ],
          choisi: Sobriete.instance.choix.index,
          onChoisi: (i) {
            Sobriete.instance.choisir(ChoixLeger.values[i]);
            maj(() {});
            setState(() {});
            _fermerFeuille(f);
          },
        ),
      ),
    ),
  );

  Future<void> _autorisation(String nom, bool actuelle, Future<void> Function(bool) changer, {bool bloquee = false}) => montrerFeuille<void>(
    context,
    titre: nom,
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LigneFeuille(
            icone: 'coche',
            texte: actuelle ? t('Autorisée') : t('Autoriser'),
            onTap: () {
              Navigator.pop(f);
              changer(true);
            },
          ),
          LigneFeuille(
            icone: 'fermer',
            texte: actuelle ? t('Ne plus autoriser') : t('Ne pas autoriser'),
            danger: actuelle,
            onTap: () {
              Navigator.pop(f);
              changer(false);
            },
          ),
          if (bloquee)
            LigneFeuille(
              icone: 'reglages',
              texte: t('Ouvrir les réglages d’Android'),
              onTap: () {
                Navigator.pop(f);
                Geolocator.openAppSettings().ignore();
              },
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final nom = s.nomAffiche;
    final email = s.email;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
          ),
          const SizedBox(height: 14),
          Titre(t('Réglages'), style: Textes.titre),
          const SizedBox(height: 18),
          Appuyable(
            semantique: t('Modifier le profil'),
            onTap: () => context.push('/profil/modifier'),
            child: Plaque(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AvatarMoi(taille: 56, nom: nom),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nom, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, color: Couleurs.discret),
                        ),
                      ],
                    ),
                  ),
                  Icone('chevron-droite', taille: 20, couleur: Couleurs.discret),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _Groupe(
            titre: t('Compte'),
            lignes: [
              _Ligne(icone: 'crayon', texte: t('Modifier le profil'), onTap: () => context.push('/profil/modifier')),
              _Ligne(icone: 'enveloppe', texte: t('E-mail et connexion'), onTap: () => context.push('/profil/acces')),
              _Ligne(
                icone: 'bloque',
                texte: t('Comptes bloqués'),
                onTap: () async {
                  await context.push('/profil/bloques');
                  setState(() {});
                },
              ),
            ],
          ),
          const _Stockage(),
          _Groupe(
            titre: t('Publications'),
            lignes: [
              _Ligne(
                icone: 'envoyer',
                texte: t('Continuer les envois hors de l’application'),
                interrupteur: Reseau.instance.envoisEnFond,
                onChanged: (v) {
                  Reseau.instance.choisir(envoisEnFond: v).then((_) => mounted ? setState(() {}) : null);
                  bulle(
                    context,
                    v
                        ? t('Vos publications continuent de s’envoyer quand vous quittez Discover. Une notification montre leur avancée.')
                        : t('Quand vous quittez Discover, Android peut arrêter les envois. Ils reprendront à votre retour.'),
                    icone: 'envoyer',
                  );
                },
              ),
            ],
          ),
          // Seulement sur les données mobiles : en Wi-Fi, tout se charge normalement.
          _Groupe(
            titre: t('Données mobiles'),
            lignes: [
              _Ligne(
                icone: 'image',
                texte: t('Économiseur de données'),
                interrupteur: Reseau.instance.economie,
                onChanged: (v) => Reseau.instance.choisir(economie: v).then((_) => mounted ? setState(() {}) : null),
              ),
              _Ligne(
                icone: 'reels',
                texte: t('Lire les reels en Wi-Fi uniquement'),
                interrupteur: Reseau.instance.reelsWifi,
                onChanged: (v) => Reseau.instance.choisir(reelsWifi: v).then((_) => mounted ? setState(() {}) : null),
              ),
              _Ligne(
                icone: 'telecharger',
                texte: t('Envoyer en Wi-Fi uniquement'),
                interrupteur: Reseau.instance.envoisWifi,
                onChanged: (v) => Reseau.instance.choisir(envoisWifi: v).then((_) => mounted ? setState(() {}) : null),
              ),
            ],
          ),
          _Groupe(
            titre: t('Affichage'),
            lignes: [
              // La langue : celle du telephone par defaut, ou une autre (ecrans/langue.dart).
              _Ligne(
                icone: 'globe',
                texte: t('Langue'),
                valeur: Langue.instance.choix == 'systeme' ? t('Langue du téléphone') : Langue.instance.nom,
                onTap: () async {
                  await context.push('/profil/reglages/langue');
                  if (mounted) setState(() {});
                },
              ),
              _Ligne(
                icone: 'theme',
                texte: t('Thème'),
                valeur: switch (Affichage.instance.mode) {
                  ModeTheme.systeme => t('Paramètre par défaut du système'),
                  ModeTheme.clair => t('Clair'),
                  ModeTheme.sombre => t('Sombre'),
                },
                onTap: _theme,
              ),
              _Ligne(
                icone: 'texte',
                texte: t('Police du téléphone'),
                interrupteur: Affichage.instance.policeDuTelephone,
                onChanged: (v) => setState(() => Affichage.instance.choisirPolice(duTelephone: v)),
              ),
              _Ligne(
                icone: 'reels',
                texte: t('Réduire les animations'),
                interrupteur: Affichage.instance.reduireAnimations,
                onChanged: (v) => setState(() => Affichage.instance.choisirAnimations(reduire: v)),
              ),
              // « Voir moins de ce lieu » : les lieux masques reviennent d un geste.
              if (Catalogue.instance.masques.isNotEmpty)
                _Ligne(
                  icone: 'oeil',
                  texte: t('Lieux masqués'),
                  valeur: t('Tout réafficher ({n})', {'n': Catalogue.instance.masques.length}),
                  onTap: () {
                    for (final id in [...Catalogue.instance.masques]) {
                      Catalogue.instance.masquer(id, oui: false);
                    }
                    setState(() {});
                    bulle(context, t('Les lieux masqués s’affichent de nouveau dans l’accueil.'), icone: 'oeil');
                  },
                ),
              // L allegement du verre : chacun le regle ; en automatique, il suit l economiseur et la memoire.
              _Ligne(
                icone: 'plume',
                texte: t('Allègement du verre'),
                valeur: switch (Sobriete.instance.choix) {
                  ChoixLeger.automatique => Sobriete.instance.leger ? t('Automatique · activé') : t('Automatique'),
                  ChoixLeger.toujours => t('Toujours'),
                  ChoixLeger.jamais => t('Jamais'),
                },
                onTap: _allegement,
              ),
            ],
          ),
          _Groupe(
            titre: t('Autorisations'),
            lignes: [
              _Ligne(
                icone: 'cible',
                texte: t('Position'),
                valeur: !s.position ? t('Refusée') : (_droitPosition == false ? t('Bloquée dans Android') : t('Autorisée')),
                onTap: () => _autorisation(t('Position'), s.position && _droitPosition != false, _changerPosition, bloquee: s.position && _droitPosition == false),
              ),
              _Ligne(
                icone: 'cloche',
                texte: t('Notifications'),
                valeur: Push.instance.bloqueesParAndroid ? t('Bloquées dans Android') : (Push.instance.actives ? t('Activées') : t('Désactivées')),
                onTap: () async {
                  await context.push('/notifications/reglages');
                  setState(() {});
                },
              ),
            ],
          ),
          _Groupe(
            titre: t('Aide et informations'),
            lignes: [
              _Ligne(icone: 'aide', texte: t('Aide'), onTap: () => context.push('/document/aide')),
              _Ligne(icone: 'bouclier', texte: t('Règles communautaires'), onTap: () => context.push('/document/regles')),
              _Ligne(icone: 'document', texte: t('Conditions générales'), onTap: () => context.push('/document/cgu')),
              _Ligne(icone: 'cadenas', texte: t('Confidentialité'), onTap: () => context.push('/document/confidentialite')),
            ],
          ),
          // La moderation (E24, /moderation) n est pas dans l application des
          // membres : elle reviendra plus tard, pour l administrateur seul.
          _Groupe(
            lignes: [
              _Ligne(
                icone: 'sortie',
                texte: t('Se déconnecter'),
                danger: true,
                onTap: () async {
                  final oui = await confirmer(
                    context,
                    titre: t('Se déconnecter ?'),
                    texte: t('Vos envois en cours seront mis en pause. Ils reprendront à votre prochaine connexion.'),
                    action: t('Se déconnecter'),
                    icone: 'sortie',
                  );
                  if (!oui || !context.mounted) return;
                  await Session.instance.deconnecter();
                  if (context.mounted) context.go('/entree');
                },
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: () => confirmerSuppressionCompte(context),
              child: Text(
                t('Supprimer mon compte'),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Couleurs.erreur),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              onTap: () => ecrireA(context, adresseSupport),
              child: Text(adresseSupport, style: TextStyle(fontSize: 12.5, color: Couleurs.discret)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Groupe extends StatelessWidget {
  const _Groupe({this.titre, required this.lignes});

  final String? titre;
  final List<_Ligne> lignes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titre != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              titre!,
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
            ),
          ),
        Plaque(
          child: Column(
            children: [
              // Le trait part du texte, comme dans les Parametres du telephone.
              for (var i = 0; i < lignes.length; i++) ...[if (i > 0) Divider(height: 1, thickness: 0.7, indent: 52, color: Couleurs.filet), lignes[i]],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Ce que Discover garde sur ce telephone : les photos deja vues (pour les
/// revoir hors ligne, sans les retelecharger) et mes publications. Le serveur,
/// lui, ne garde que ce que les autres doivent voir.
class _Stockage extends StatefulWidget {
  const _Stockage();

  @override
  State<_Stockage> createState() => _StockageState();
}

class _StockageState extends State<_Stockage> {
  int? _octets;

  @override
  void initState() {
    super.initState();
    _mesurer();
  }

  Future<void> _mesurer() async {
    final n = await ImagesReseau.taille() + await Videos.instance.taille();
    if (mounted) setState(() => _octets = n);
  }

  static String _taille(int o) => o < 1024 * 1024 ? t('{n} Ko', {'n': (o / 1024).round()}) : t('{n} Mo', {'n': (o / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')});

  @override
  Widget build(BuildContext context) => _Groupe(
    titre: t('Stockage sur ce téléphone'),
    lignes: [
      _Ligne(
        icone: 'image',
        texte: t('Photos et vidéos disponibles hors connexion'),
        valeur: _octets == null ? '…' : _taille(_octets!),
        onTap: () => bulle(context, t('Les photos et vidéos déjà vues sont conservées sur ce téléphone (500 Mo maximum). Elles s’affichent sans connexion et ne sont pas téléchargées de nouveau.')),
      ),
      _Ligne(
        icone: 'poubelle',
        texte: t('Supprimer les photos et vidéos conservées'),
        onTap: () async {
          await ImagesReseau.vider();
          await Videos.instance.vider();
          await _mesurer();
          if (context.mounted) bulle(context, t('Photos et vidéos supprimées. Elles seront téléchargées de nouveau si nécessaire.'), icone: 'coche');
        },
      ),
      _Ligne(
        icone: 'telephone',
        texte: t('Mes originaux'),
        valeur: t('Sur ce téléphone'),
        onTap: () => bulle(context, t('Vos photos et vidéos d’origine restent sur votre téléphone. Discover les vérifie, puis ne conserve que les tailles affichées.'), icone: 'telephone'),
      ),
    ],
  );
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.texte, this.valeur, this.onTap, this.interrupteur, this.onChanged, this.danger = false});

  final String icone;
  final String texte;
  final String? valeur;
  final VoidCallback? onTap;
  final bool? interrupteur;
  final ValueChanged<bool>? onChanged;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final couleur = danger ? Couleurs.erreur : Couleurs.texte;
    final ligne = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Mesures.hautLigne),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
        child: Row(
          children: [
            Icone(icone, taille: 22, couleur: couleur),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                texte,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: couleur),
              ),
            ),
            if (valeur != null) ...[Text(valeur!, style: TextStyle(fontSize: 14.5, color: Couleurs.discret)), const SizedBox(width: 6)],
            if (interrupteur != null)
              Switch(
                value: interrupteur!,
                activeTrackColor: Couleurs.ocean,
                inactiveTrackColor: Couleurs.pisteEteinte,
                inactiveThumbColor: Colors.white,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                onChanged: onChanged,
              )
            else if (!danger)
              Icone('chevron-droite', taille: 18, couleur: Couleurs.chevron),
          ],
        ),
      ),
    );
    if (interrupteur != null) return MergeSemantics(child: ligne);
    return InkWell(onTap: onTap, child: ligne);
  }
}

/// E21 : modifier le profil.
class EcranModifierProfil extends StatefulWidget {
  const EcranModifierProfil({super.key});

  @override
  State<EcranModifierProfil> createState() => _EcranModifierProfilState();
}

class _EcranModifierProfilState extends State<EcranModifierProfil> {
  final s = Session.instance;
  late final _nom = TextEditingController(text: s.nomAffiche);
  late final _pseudo = TextEditingController(text: s.nomUtilisateur);
  late final _bio = TextEditingController(text: s.bio);
  late final _site = TextEditingController(text: s.site);
  late String _pays = s.pays;
  late String _ville = s.ville;
  bool _attente = false;

  @override
  void dispose() {
    for (final c in [_nom, _pseudo, _bio, _site]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _terminer() async {
    if (Api.instance.jeton == null) return bulle(context, t('Connectez-vous pour modifier votre profil.'), icone: 'profil');
    // Refuse par le serveur : la session reprend ce qu elle avait.
    final avant = (s.nomAffiche, s.nomUtilisateur, s.bio, s.site, s.pays, s.ville);
    void remettre() => s
      ..nomAffiche = avant.$1
      ..nomUtilisateur = avant.$2
      ..bio = avant.$3
      ..site = avant.$4
      ..pays = avant.$5
      ..ville = avant.$6;
    s
      ..nomAffiche = _nom.text.trim()
      ..nomUtilisateur = _pseudo.text.trim().replaceFirst('@', '').toLowerCase()
      ..bio = _bio.text.trim()
      ..site = _site.text.trim()
      ..pays = _pays
      ..ville = _ville;
    setState(() => _attente = true);
    try {
      await s.envoyerProfil();
    } on ErreurApi catch (e) {
      remettre();
      if (mounted) {
        setState(() => _attente = false);
        bulle(context, e.message, icone: 'alerte');
      }
      return;
    } on ApiInjoignable {
      remettre();
      if (mounted) {
        setState(() => _attente = false);
        bulle(context, t('Aucune connexion. Réessayez dans un instant.'), icone: 'hors-ligne');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _attente = false);
    bulle(context, t('Profil enregistré.'));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              Expanded(
                child: Text(
                  t('Modifier le profil'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              BoutonVerre(texte: t('Enregistrer'), plein: true, large: false, enCours: _attente, onTap: _attente ? null : _terminer),
            ],
          ),
          const SizedBox(height: 10),
          Text(t('Ces informations sont visibles par tous, à côté de vos photos.'), style: Textes.discret, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ValueListenableBuilder(
                  valueListenable: _nom,
                  builder: (context, v, _) => AvatarMoi(nom: v.text.isEmpty ? 'U' : v.text, taille: 104),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: RondVerre(icone: 'camera', semantique: t('Changer la photo de profil'), taille: 40, onTap: () => choisirPhotoProfil(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ChampVerre(libelle: t('Nom affiché'), icone: 'profil', controleur: _nom),
          const SizedBox(height: 16),
          ChampVerre(libelle: t('Nom d’utilisateur'), icone: 'arobase', controleur: _pseudo),
          const SizedBox(height: 16),
          ValueListenableBuilder(
            valueListenable: _bio,
            builder: (context, v, _) => ChampVerre(
              libelle: t('Bio'),
              icone: 'crayon',
              controleur: _bio,
              lignes: 3,
              aide: Text(t('{n}/160', {'n': v.text.length})),
              erreur: v.text.length > 160 ? t('Saisissez 160 caractères au maximum.') : null,
            ),
          ),
          const SizedBox(height: 16),
          ChampVerre(libelle: t('Site Web'), icone: 'lien', controleur: _site, facultatif: true, clavier: TextInputType.url),
          const SizedBox(height: 16),
          ChoixPaysVille(
            pays: _pays,
            ville: _ville,
            onChanged: (pays, ville) => setState(() {
              _pays = pays;
              _ville = ville;
            }),
          ),
        ],
      ),
    );
  }
}

/// E21 : l e-mail du compte et la facon d entrer (un code, ou Google).
class EcranAcces extends StatelessWidget {
  const EcranAcces({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Session.instance,
    builder: (context, _) {
      final s = Session.instance;
      return _PageReglage(
        titre: t('E-mail et connexion'),
        enfants: [
          _Groupe(
            titre: t('Adresse e-mail'),
            lignes: [
              s.google
                  ? _Ligne(
                      icone: 'enveloppe',
                      texte: s.email,
                      valeur: t('Gérée par Google'),
                      onTap: () => bulle(context, t('Pour la modifier, changez l’adresse de votre compte Google.'), icone: 'google'),
                    )
                  : _Ligne(icone: 'enveloppe', texte: s.email, valeur: t('Modifier'), onTap: () => ouvrirChangerEmail(context)),
            ],
          ),
          _Groupe(
            titre: t('Méthodes de connexion'),
            lignes: [if (s.google) _Ligne(icone: 'google', texte: 'Google', valeur: t('Associé')) else _Ligne(icone: 'enveloppe', texte: t('Code envoyé par e-mail'), valeur: t('Activé'))],
          ),
          Text(
            s.google
                ? t('Vous vous connectez avec votre compte Google.')
                : t('À chaque connexion, un code à 6 chiffres valable 10 minutes est envoyé à votre adresse. Aucun mot de passe n’est nécessaire.'),
            style: Textes.petit,
          ),
        ],
      );
    },
  );
}

/// E21 : les comptes bloques. Ils ne voient plus vos publications et ne
/// peuvent plus vous ecrire ; ils ne sont pas prevenus.
class EcranBloques extends StatefulWidget {
  const EcranBloques({super.key});

  @override
  State<EcranBloques> createState() => _EcranBloquesState();
}

class _EcranBloquesState extends State<EcranBloques> {
  /// Avec un compte : ceux du serveur (nom, pseudo, photo).
  List<(String, String, String?)>? _serveur;

  @override
  void initState() {
    super.initState();
    Communaute.instance.mesBlocages().then((l) {
      if (mounted && l != null) setState(() => _serveur = l);
    });
  }

  List<(String, String)> get _bloques => [for (final b in _serveur ?? const <(String, String, String?)>[]) (b.$1, b.$2)];

  Future<void> _debloquer(int i) async {
    final (nom, pseudo) = _bloques[i];
    if (await Communaute.instance.bloquer(pseudo, false) == null) {
      if (mounted) bulle(context, t('Impossible de débloquer ce compte. Réessayez.'), icone: 'alerte');
      return;
    }
    if (!mounted) return;
    setState(() => _serveur!.removeAt(i));
    bulle(context, t('Vous avez débloqué {nom}.', {'nom': nom}));
  }

  @override
  Widget build(BuildContext context) => _PageReglage(
    titre: t('Comptes bloqués'),
    enfants: [
      Text(t('Ces comptes ne peuvent plus voir vos publications ni vous écrire. Ils ne sont pas informés que vous les avez bloqués.'), style: Textes.discret),
      const SizedBox(height: 18),
      if (_serveur == null)
        const SizedBox.shrink()
      else if (_bloques.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(t('Aucun compte bloqué'), textAlign: TextAlign.center, style: Textes.discret),
        )
      else
        Plaque(
          child: Column(
            children: [
              for (var i = 0; i < _bloques.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 0.7, indent: 70, color: Couleurs.filet),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Avatar(nom: _bloques[i].$1, taille: 44, photo: _serveur?[i].$3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_bloques[i].$1, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                            Text('@${_bloques[i].$2}', style: TextStyle(fontSize: 13, color: Couleurs.discret)),
                          ],
                        ),
                      ),
                      BoutonVerre(texte: t('Débloquer'), large: false, onTap: () => _debloquer(i)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

/// E17 : ce qui envoie une notification. Tout se regle d un interrupteur ;
/// une publication retiree previent toujours (on doit savoir pourquoi).
class EcranReglagesNotifications extends StatefulWidget {
  const EcranReglagesNotifications({super.key});

  @override
  State<EcranReglagesNotifications> createState() => _EcranReglagesNotificationsState();
}

class _EcranReglagesNotificationsState extends State<EcranReglagesNotifications> {
  final _push = Push.instance;

  // Au retour des reglages d Android, la permission est relue.
  late final AppLifecycleListener _cycle;

  @override
  void initState() {
    super.initState();
    _cycle = AppLifecycleListener(onResume: _relire);
    _relire();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  Future<void> _relire() async {
    await _push.lirePermission();
    if (mounted) setState(() {});
  }

  void _changer(VoidCallback f) {
    setState(f);
    _push.changer().ignore();
  }

  _Ligne _choix(String cle, String icone, String texte) => _Ligne(icone: icone, texte: texte, interrupteur: _push.choix[cle], onChanged: (v) => _changer(() => _push.choix[cle] = v));

  @override
  Widget build(BuildContext context) {
    final actives = _push.actives && !_push.enPause;
    // Coupees ou en pause : le detail reste visible, en retrait.
    Widget detail(Widget enfant) => AnimatedOpacity(
      opacity: actives ? 1 : 0.4,
      duration: Durees.interface,
      child: IgnorePointer(ignoring: !actives, child: enfant),
    );
    return _PageReglage(
      titre: t('Notifications'),
      enfants: [
        // Android a le dernier mot : bloquees chez lui, rien n arrive, quels que soient ces choix.
        if (_push.bloqueesParAndroid) ...[
          _Groupe(
            lignes: [_Ligne(icone: 'alerte', texte: t('Bloquées dans Android'), valeur: t('Réglages'), onTap: () => Geolocator.openAppSettings().ignore())],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Text(t('Android empêche Discover d’envoyer des notifications. Pour les recevoir, autorisez-les dans les réglages d’Android.'), style: Textes.petit),
          ),
        ],
        _Groupe(
          lignes: [
            _Ligne(icone: 'cloche', texte: t('Autoriser les notifications'), interrupteur: _push.actives, onChanged: (v) => _changer(() => _push.actives = v)),
            _Ligne(
              icone: 'pause',
              texte: t('Tout suspendre pendant 8 heures'),
              interrupteur: _push.enPause,
              onChanged: _push.actives ? (v) => _changer(() => _push.pauseJusqua = v ? DateTime.now().add(const Duration(hours: 8)) : null) : null,
            ),
          ],
        ),
        detail(
          _Groupe(
            titre: t('Votre activité'),
            lignes: [
              _choix('jaime', 'coeur', t('J’aime et réactions')),
              _choix('commentaires', 'commentaire', t('Commentaires et réponses')),
              _choix('mentions', 'arobase', t('Mentions')),
              _choix('abonnes', 'profil', t('Nouveaux abonnés')),
            ],
          ),
        ),
        detail(
          _Groupe(
            titre: t('Vos publications'),
            lignes: [
              _choix('verifiee', 'verifie', t('Publication en ligne')),
              // Toujours envoyée : le motif et le recours doivent arriver.
              _Ligne(icone: 'drapeau', texte: t('Publication retirée'), valeur: t('Toujours activée')),
            ],
          ),
        ),
        detail(_Groupe(titre: t('Comptes suivis'), lignes: [_choix('suivis', 'image', t('Nouvelles publications'))])),
        Text(t('Si une publication est retirée, vous recevez toujours une notification avec le motif. Vous pouvez demander une seconde vérification une seule fois.'), style: Textes.petit),
      ],
    );
  }
}

/// Une sous-page des reglages : le retour, le titre au centre, le contenu.
class _PageReglage extends StatelessWidget {
  const _PageReglage({required this.titre, required this.enfants});

  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              Expanded(
                child: Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 22),
          ...enfants,
        ],
      ),
    );
  }
}
