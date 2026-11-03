// E36 Completer le profil, a la premiere connexion (e-mail ou Google), en
// trois etapes : photo et noms ; pays, ville et position ; types de lieux aimes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../donnees/capture.dart';
import '../../donnees/modeles.dart';
import '../../donnees/session.dart';
import '../../outils/api.dart';
import '../../outils/appareil.dart';
import '../../outils/langue.dart';
import '../../outils/photo_profil.dart';
import '../../widgets/avatar.dart';
import '../../theme/jetons.dart';
import '../../theme/theme.dart';
import '../../widgets/champ.dart';
import '../../widgets/choix_pays_ville.dart';
import '../../widgets/icone.dart';
import '../../widgets/mouvement.dart';
import '../../widgets/page.dart';
import '../../widgets/photo.dart';
import '../../widgets/verre.dart';

class EcranCompleter extends StatelessWidget {
  const EcranCompleter({super.key, required this.etape});

  final int etape;

  @override
  Widget build(BuildContext context) => switch (etape) {
    1 => const _Etape1(),
    2 => const _Etape2(),
    _ => const _Etape3(),
  };
}

/// L en-tete commun : les trois traits, retour, « Etape n sur 3 ».
class _Entete extends StatelessWidget {
  const _Entete({required this.etape, this.passer});

  final int etape;
  final VoidCallback? passer;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Progression(etape: etape - 1),
      const SizedBox(height: 14),
      Row(
        children: [
          RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/entree')),
          const SizedBox(width: 12),
          Text(t('Étape {n} sur 3', {'n': etape}), style: Textes.petit.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (passer != null) Lien(t('Passer'), discret: true, onTap: passer),
        ],
      ),
    ],
  );
}

class _Cadre extends StatelessWidget {
  const _Cadre({required this.enfants, this.bas});

  final List<Widget> enfants;
  final Widget? bas;

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(padding: EdgeInsets.fromLTRB(marge, 8, marge, 16), children: enfants),
                ),
                if (bas != null) Padding(padding: EdgeInsets.fromLTRB(marge, 0, marge, 16), child: bas),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etape1 extends StatefulWidget {
  const _Etape1();

  @override
  State<_Etape1> createState() => _Etape1State();
}

class _Etape1State extends State<_Etape1> {
  final s = Session.instance;
  late final _nom = TextEditingController(text: s.nomAffiche);
  late final _utilisateur = TextEditingController(text: s.nomUtilisateur);
  late final _bio = TextEditingController(text: s.bio);

  // Le nom est libre (vrai), deja pris (faux), ou pas encore verifie (nul).
  bool? _libre;
  String? _pris;
  bool _verifie = false;
  Timer? _pause;

  @override
  void initState() {
    super.initState();
    _verifierPlusTard();
  }

  @override
  void dispose() {
    _pause?.cancel();
    _nom.dispose();
    _utilisateur.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _utilisateurValide => RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(_utilisateur.text);

  // Une courte pause dans la saisie, puis le serveur dit si le nom est libre.
  void _verifierPlusTard() {
    _pause?.cancel();
    _libre = null;
    _pris = null;
    _verifie = false;
    if (!_utilisateurValide || Api.instance.jeton == null) return;
    _verifie = true;
    _pause = Timer(const Duration(milliseconds: 400), _verifier);
  }

  Future<void> _verifier() async {
    final nom = _utilisateur.text;
    bool? libre;
    String? message;
    try {
      final r = await Api.instance.get('auth/nom-libre?nom=${Uri.encodeQueryComponent(nom)}');
      libre = r.json['libre'] == true;
      message = r.json['message'] as String?;
    } on ApiInjoignable {
      // Hors ligne : le serveur verifiera a la fin.
    } on ErreurApi {
      // Le serveur repondra a la fin.
    }
    if (!mounted || _utilisateur.text != nom) return;
    setState(() {
      _verifie = false;
      _libre = libre;
      _pris = libre == false ? (message ?? t('Ce nom d’utilisateur est déjà pris.')) : null;
    });
  }

  @override
  Widget build(BuildContext context) => _Cadre(
    enfants: [
      const _Entete(etape: 1),
      const SizedBox(height: 18),
      Titre(t('Votre profil'), style: Textes.titre),
      const SizedBox(height: 8),
      Monte(
        delai: const Duration(milliseconds: 300),
        child: Text(t('Ce que les autres verront à côté de vos photos.'), style: Textes.discret),
      ),
      const SizedBox(height: 22),
      Center(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Toucher la photo ouvre le meme choix que le lien dessous.
                Appuyable(
                  semantique: t('Ajouter une photo de profil'),
                  onTap: () => choisirPhotoProfil(context),
                  child: ListenableBuilder(
                    listenable: s,
                    builder: (context, _) => s.photo != null
                        ? Avatar(nom: s.nomAffiche, taille: 96, photo: s.photo)
                        : Container(
                            width: 96,
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Couleurs.ocean, shape: BoxShape.circle),
                            child: Text(
                              s.initiales,
                              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    // La pastille suit le theme : blanche le jour, gris fonce la
                    // nuit, cerclee du fond pour se detacher de l avatar.
                    decoration: BoxDecoration(
                      color: Couleurs.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: Couleurs.fond, width: 2.5),
                    ),
                    child: Icone('camera', taille: 18, couleur: Couleurs.texte),
                  ),
                ),
              ],
            ),
            ListenableBuilder(
              listenable: s,
              builder: (context, _) => Lien(s.photo == null ? t('Ajouter une photo') : t('Changer la photo'), onTap: () => choisirPhotoProfil(context)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ChampVerre(libelle: t('Nom affiché'), icone: 'profil', controleur: _nom, onChanged: (_) => setState(() {}), aide: Text(t('Tiré de votre adresse e-mail. Vous pouvez le modifier.'))),
      const SizedBox(height: 16),
      ChampVerre(
        libelle: t("Nom d'utilisateur"),
        icone: 'arobase',
        controleur: _utilisateur,
        onChanged: (_) => setState(_verifierPlusTard),
        suffixe: _libre == true ? Icone('coche', taille: 20, couleur: Couleurs.succes) : null,
        erreur: _utilisateur.text.isEmpty || _utilisateurValide ? _pris : t('Utilisez de 3 à 30 caractères : lettres minuscules, chiffres, points ou traits de soulignement.'),
        aide: _verifie
            ? Text(t('Vérification…'))
            : _libre == true
            ? Row(
                children: [
                  Icone('coche', taille: 15, couleur: Couleurs.succes),
                  const SizedBox(width: 5),
                  Text(t('Ce nom d’utilisateur est disponible')),
                ],
              )
            : null,
      ),
      const SizedBox(height: 16),
      ChampVerre(libelle: t('Bio'), facultatif: true, icone: 'crayon', indice: t('Ce que vous aimez photographier, en une phrase'), controleur: _bio, lignes: 3),
    ],
    bas: BoutonVerre(
      texte: t('Continuer'),
      plein: true,
      onTap: _nom.text.trim().isNotEmpty && _utilisateurValide && _libre != false && !_verifie
          ? () {
              s
                ..nomAffiche = _nom.text.trim()
                ..nomUtilisateur = _utilisateur.text
                ..bio = _bio.text.trim();
              context.push('/completer/2');
            }
          : null,
    ),
  );
}

class _Etape2 extends StatefulWidget {
  const _Etape2();

  @override
  State<_Etape2> createState() => _Etape2State();
}

class _Etape2State extends State<_Etape2> {
  final s = Session.instance;
  bool _cherche = false;
  String? _trouve;

  @override
  void initState() {
    super.initState();
    // Des l arrivee sur l ecran, la fenetre du systeme propose d activer la
    // localisation ; acceptee, le pays et la ville se remplissent seuls.
    WidgetsBinding.instance.addPostFrameCallback((_) => _localiser());
  }

  // La position, puis son nom par Android : le pays et la ville se remplissent.
  Future<void> _localiser({bool demander = true}) async {
    setState(() => _cherche = true);
    if (demander) {
      final pret = await demanderLocalisation();
      if (mounted) setState(() => s.position = pret);
      if (!pret) {
        if (!mounted) return;
        setState(() {
          _cherche = false;
          _trouve = positionManquee == SansPosition.refusee ? t('Discover n’a pas accès à votre position.') : null;
        });
        return;
      }
    }
    final p = await positionActuelle(demander: false);
    final a = p == null ? null : await Appareil.adresse(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      _cherche = false;
      if (a != null && a.pays.isNotEmpty) {
        s.pays = a.pays;
        s.ville = a.ville.isNotEmpty ? a.ville : (a.region.isNotEmpty ? a.region : s.ville);
        _trouve = t('Trouvé : {ville}, {pays}', {'ville': s.ville, 'pays': s.pays});
      } else if (demander) {
        s.position = p != null;
        _trouve = switch (positionManquee) {
          SansPosition.coupee => t('La localisation est désactivée sur ce téléphone.'),
          SansPosition.refusee => t('Discover n’a pas accès à votre position.'),
          _ => p != null ? t('Une connexion Internet est nécessaire pour trouver votre ville. Choisissez-la ci-dessus.') : t('Impossible de trouver votre position pour le moment.'),
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) => _Cadre(
    enfants: [
      const _Entete(etape: 2),
      const SizedBox(height: 18),
      Titre(t("D'où êtes-vous ?"), style: Textes.titre),
      const SizedBox(height: 8),
      Monte(
        delai: const Duration(milliseconds: 300),
        child: Text(t("Votre ville s'affiche sur votre profil."), style: Textes.discret),
      ),
      const SizedBox(height: 24),
      ChoixPaysVille(
        pays: s.pays,
        ville: s.ville,
        onChanged: (pays, ville) => setState(() {
          s.pays = pays;
          s.ville = ville;
        }),
      ),
      const SizedBox(height: 18),
      Plaque(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // A l encre, comme toutes les icones de l interface : pas de pastille bleue.
            Icone('cible', taille: 24, couleur: Couleurs.texte),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Utiliser ma position'), style: Textes.libelle),
                  const SizedBox(height: 2),
                  Text(
                    _cherche ? t('Recherche de votre position…') : _trouve ?? t('Pour vous montrer les lieux proches. Vous pouvez changer ce choix à tout moment dans les réglages.'),
                    style: Textes.petit,
                  ),
                ],
              ),
            ),
            Switch(
              value: s.position,
              activeTrackColor: Couleurs.ocean,
              onChanged: (v) {
                setState(() => s.position = v);
                if (v) _localiser();
              },
            ),
          ],
        ),
      ),
    ],
    bas: BoutonVerre(texte: t('Continuer'), plein: true, onTap: () => context.push('/completer/3')),
  );
}

class _Etape3 extends StatefulWidget {
  const _Etape3();

  @override
  State<_Etape3> createState() => _Etape3State();
}

class _Etape3State extends State<_Etape3> {
  final s = Session.instance;

  bool _attente = false;

  // L accueil tout de suite, comme les autres reseaux : le profil et la photo partent derriere
  // (renvoyes plus tard sans reseau). Un nom d utilisateur pris entre-temps ramene a l etape 1.
  Future<void> _terminer() async {
    if (_attente) return;
    setState(() => _attente = true);
    // Le navigateur racine reste la apres le changement de page : de quoi prevenir ensuite.
    final racine = Navigator.of(context, rootNavigator: true).context;
    unawaited(s.profilEnAttente());
    context.go('/accueil');
    bulle(racine, t('Bienvenue sur Discover, {prenom}.', {'prenom': s.nomAffiche.split(' ').first}));
    try {
      await s.envoyerProfil(complet: true);
      await s.envoyerPhoto();
      await s.profilEnvoye();
    } on ErreurApi catch (e) {
      if (!racine.mounted) return;
      bulle(racine, e.message, icone: 'alerte');
      if (e.erreurs.containsKey('nom_utilisateur')) GoRouter.of(racine).go('/completer/1');
    } catch (_) {
      // Sans reseau : il part a la prochaine ouverture (profilEnAttente).
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = s.interets.length;
    final colonnes = MediaQuery.sizeOf(context).width >= 600 ? 4 : 3;
    return _Cadre(
      enfants: [
        _Entete(etape: 3, passer: _terminer),
        const SizedBox(height: 18),
        Titre(t('Ce que vous aimez voir'), style: Textes.titre),
        const SizedBox(height: 8),
        Monte(
          delai: const Duration(milliseconds: 300),
          child: Text(t('Choisissez au moins 3 thèmes. Votre fil les affichera en premier.'), style: Textes.discret),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: colonnes,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.8,
          children: [
            for (var i = 0; i < themesAimes.length; i++)
              Monte(
                delai: Duration(milliseconds: 350 + 40 * i),
                child: _Interet(
                  nom: themesAimes[i].nom,
                  photo: 'assets/interets/${themesAimes[i].cle}.webp',
                  choisi: s.interets.contains(themesAimes[i].cle),
                  onTap: () => setState(() {
                    final cle = themesAimes[i].cle;
                    if (!s.interets.remove(cle)) s.interets.add(cle);
                  }),
                ),
              ),
          ],
        ),
      ],
      bas: BoutonVerre(texte: n >= 3 ? t('Terminer · {n} choisis', {'n': n}) : tn(3 - n, 'Encore {n} à choisir', 'Encore {n} à choisir'), plein: true, onTap: n >= 3 && !_attente ? _terminer : null),
    );
  }
}

class _Interet extends StatelessWidget {
  const _Interet({required this.nom, required this.photo, required this.choisi, required this.onTap});

  final String nom;
  final String photo;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Appuyable(
    onTap: onTap,
    semantique: choisi ? t('{nom}, choisi', {'nom': t(nom)}) : t(nom),
    child: AnimatedContainer(
      duration: Durees.interface,
      curve: Courbes.interface,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: choisi ? Couleurs.ocean : Colors.transparent, width: 2.5),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Photo(photo),
            // Le nom sur un fond sombre uni : lisible sur toutes les photos.
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(9)),
                child: Text(
                  t(nom),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedScale(
                scale: choisi ? 1 : 0,
                duration: Durees.relache,
                curve: Courbes.ressort,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Couleurs.ocean, shape: BoxShape.circle),
                  child: const Icone('coche', taille: 15, couleur: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
