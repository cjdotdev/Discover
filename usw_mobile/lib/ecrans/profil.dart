// E18 Mon profil, E19 Collection, E20 Createur : la tete du profil (avatar,
// nom, pseudo, bio, ville), puis ses publications en mosaique plate facon
// Pinterest. Mon profil a aussi ses reels et ses enregistrements (les
// collections). Tout vient du serveur (moi, utilisateurs/{pseudo}, collections).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../outils/langue.dart';
import '../outils/partage.dart';
import '../outils/chemins.dart';
import '../outils/verrou.dart';
import '../donnees/catalogue.dart';
import 'etats.dart';
import '../donnees/communaute.dart';
import '../donnees/modeles.dart';
import '../donnees/lieux_enregistres.dart' show nombrePublications;
import '../donnees/lifestyle.dart';
import '../donnees/mes_publications.dart';
import '../donnees/session.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/feuille.dart';
import '../widgets/feuilles.dart';
import '../widgets/icone.dart';
import '../widgets/mosaique.dart';
import '../widgets/mouvement.dart';
import '../widgets/options.dart';
import '../widgets/page.dart';
import '../widgets/verre.dart';
import 'visionneuse.dart';

String _nombre(int n) => n < 1000 ? '$n' : '${n ~/ 1000} ${(n % 1000).toString().padLeft(3, '0')}';

/// Un compteur traduit (« 12 abonnés »), le nombre en gras, ou qu il soit dans la phrase.
List<TextSpan> _compteur(int n, String texte) {
  final i = texte.indexOf('$n');
  if (i < 0) return [TextSpan(text: texte)];
  return [
    if (i > 0) TextSpan(text: texte.substring(0, i)),
    TextSpan(
      text: _nombre(n),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    TextSpan(text: texte.substring(i + '$n'.length)),
  ];
}

/// Le site d un profil, sans « https:// » ni barre finale : « monsite.bj ».
String _siteLisible(String site) => site.trim().replaceFirst(RegExp(r'^https?://', caseSensitive: false), '').replaceFirst(RegExp(r'/+$'), '');

// Ouvrir le site dans le navigateur ; un message s il n a pas pu s ouvrir.
Future<void> _ouvrirSite(BuildContext context, String site) async {
  final brut = site.trim();
  final adresse = Uri.tryParse(RegExp(r'^https?://', caseSensitive: false).hasMatch(brut) ? brut : 'https://$brut');
  var ouvert = false;
  try {
    ouvert = adresse != null && await launchUrl(adresse, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ouvert && context.mounted) bulle(context, t('Impossible d’ouvrir le site. Réessayez.'), icone: 'alerte');
}

/// La tete d un profil.
class _Tete extends StatelessWidget {
  const _Tete({required this.nom, required this.pseudo, required this.bio, required this.ville, this.photo, this.abonnes, this.abonnements, this.moi = false, this.site});

  final String nom;
  final String pseudo;
  final String bio;
  final String ville;
  final int? abonnes;
  final int? abonnements;

  /// Le profil du membre connecte : sa photo, des qu il en a une.
  final bool moi;

  /// La photo d un createur (son adresse sur le serveur).
  final String? photo;

  /// Son site web (vide ou nul : aucun), ouvert d un toucher.
  final String? site;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // La photo s agrandit d un toucher ; la mienne suit mes changements.
      if (moi)
        ListenableBuilder(
          listenable: Session.instance,
          builder: (context, _) => AvatarAgrandissable(nom: nom, photo: Session.instance.photo ?? Session.instance.avatar),
        )
      else
        AvatarAgrandissable(nom: nom, photo: photo),
      const SizedBox(height: 14),
      Semantics(
        header: true,
        child: Monte(
          child: Text(
            nom,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: Couleurs.texte),
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text('@$pseudo', style: TextStyle(fontSize: 14.5, color: Couleurs.discret)),
      if (bio.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          bio,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texte),
        ),
      ],
      if (ville.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icone('lieu', taille: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                ville,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.discret),
              ),
            ),
          ],
        ),
      ],
      if (site != null && _siteLisible(site!).isNotEmpty) ...[
        const SizedBox(height: 6),
        Appuyable(
          semantique: t('Site Web : {site}', {'site': _siteLisible(site!)}),
          onTap: () => _ouvrirSite(context, site!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icone('lien', taille: 16, couleur: Couleurs.texte),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _siteLisible(site!),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.texte, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      if (abonnes != null) ...[
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              ..._compteur(abonnes!, tn(abonnes!, '{n} abonné', '{n} abonnés')),
              if (abonnements != null) ...[const TextSpan(text: '  ·  '), ..._compteur(abonnements!, tn(abonnements!, '{n} abonnement', '{n} abonnements'))],
            ],
          ),
          style: TextStyle(fontSize: 14, color: Couleurs.texte),
        ),
      ],
    ],
  );
}

/// Les onglets d un profil : le texte actif, souligne d un trait qui glisse.
class _Onglets extends StatelessWidget {
  const _Onglets({required this.noms, required this.actif, required this.onChange});

  final List<String> noms;
  final int actif;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < noms.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          GestureDetector(
            onTap: () => onChange(i),
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              selected: i == actif,
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: Durees.interface,
                      style: TextStyle(fontFamily: famillePolice, fontSize: 16, fontWeight: FontWeight.w600, color: i == actif ? Couleurs.texte : Couleurs.discret),
                      child: Text(noms[i]),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      // Le trait qui arrive rebondit ; celui qui part s efface sans
                      // rebond (sous zero, sa largeur deviendrait negative).
                      curve: i == actif ? Courbes.ressort : Curves.easeOutCubic,
                      height: 3,
                      width: i == actif ? 34 : 0,
                      decoration: BoxDecoration(color: Couleurs.texte, borderRadius: BorderRadius.circular(2)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Le haut d une page de profil : des boutons de verre, a plat sur le fond.
class _Haut extends StatelessWidget {
  const _Haut({required this.gauche, required this.droite});

  final Widget gauche;
  final List<Widget> droite;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      gauche,
      const Spacer(),
      for (var i = 0; i < droite.length; i++) ...[if (i > 0) const SizedBox(width: 6), droite[i]],
    ],
  );
}

// Une de mes publications : sa page (commentaires, fiche de capture) des qu elle est sur le
// serveur ; avant, la photo en plein ecran, ou le reel qui se lit.
void _mienne(BuildContext context, MaPublication p) => p.contenu != null
    ? context.push('/profil/lieu/_/photo/${p.contenu}')
    : p.video != null
    ? ouvrirLecture(context, p.video!, affiche: p.photo)
    : ouvrirVisionneuse(context, p.photo);

/// E18 : mon profil.
class EcranProfil extends StatefulWidget {
  const EcranProfil({super.key});

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  int _onglet = 0;

  /// Mes publications en ligne (nul : pas encore arrivees).
  List<Publication>? _enLigne;

  bool get _compte => Communaute.instance.enLigne;

  @override
  void initState() {
    super.initState();
    if (_compte) {
      Catalogue.instance.mesContenus().then((p) {
        if (mounted && p != null) setState(() => _enLigne = p);
      });
      Session.instance.rafraichir();
      Communaute.instance.chargerCollections();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([MesPublications.instance, Session.instance, Communaute.instance, Catalogue.instance]),
    builder: (context, _) => _compte ? _construire(context) : const _SansCompte(),
  );

  Widget _construire(BuildContext context) {
    final s = Session.instance;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final nom = s.nomAffiche.isEmpty ? s.nomUtilisateur : s.nomAffiche;
    final pseudo = s.nomUtilisateur;
    final locales = MesPublications.instance.contenus;
    final serveur = [
      // Une publication supprimee d ici part tout de suite (la liste du serveur date de l ouverture).
      for (final p in _enLigne ?? const <Publication>[])
        if (!locales.contains(p.id) && !Catalogue.instance.supprimees.contains(p.id) && (_onglet == 0 || p.reel)) p,
    ];
    // Ce que j ai publie depuis ce telephone, en tete ; puis le reste, du serveur.
    final miennes = _onglet == 2
        ? const <MaPublication>[]
        : [
            for (final p in MesPublications.instance.liste)
              if (_onglet == 0 || p.video != null) p,
          ];
    final n = miennes.length;
    final aucune = miennes.isEmpty && serveur.isEmpty;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, haut + 8, 0, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: marge),
            child: _Haut(
              gauche: RondVerre(
                icone: 'partager',
                semantique: t('Partager le profil'),
                onTap: () => feuillePartager(
                  context,
                  titre: nom,
                  sousTitre: s.abonnes == null ? '@$pseudo' : '@$pseudo · ${tn(s.abonnes!, '{n} abonné', '{n} abonnés')}',
                  // Mon profil : ma photo de profil, comme en tete de l ecran (ou mes initiales).
                  photo: s.photo ?? s.avatar ?? '',
                  profil: true,
                  lien: '$domainePublic/@$pseudo',
                ),
              ),
              droite: [
                RondVerre(icone: 'telecharger', semantique: t('Mes envois'), onTap: () => context.push('/creer/envois')),
                RondVerre(icone: 'reglages', semantique: t('Réglages'), onTap: () => context.push('/profil/reglages')),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 6, marge, 18),
            // Les compteurs viennent du serveur : rien tant qu il n a pas repondu.
            child: _Tete(moi: true, nom: nom, pseudo: pseudo, bio: s.bio, ville: [s.ville, s.pays].where((x) => x.isNotEmpty).join(', '), site: s.site, abonnes: s.abonnes, abonnements: s.abonnements),
          ),
          // Mon lifestyle : ma vie, hors de l accueil de Discover.
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 0, marge, 18),
            child: ListenableBuilder(
              listenable: Lifestyle.instance,
              builder: (context, _) {
                final l = Lifestyle.instance;
                final vide = (l.miennes?.isEmpty ?? true) && l.brouillons.isEmpty;
                return Plaque(
                  child: LigneFeuille(icone: 'image', texte: vide ? t('Créer mon lifestyle') : t('Mon lifestyle'), onTap: () => context.push('/profil/lifestyle')),
                );
              },
            ),
          ),
          _Onglets(noms: [t('Publications'), t('Reels'), t('Enregistrés')], actif: _onglet, onChange: (i) => setState(() => _onglet = i)),
          const SizedBox(height: 12),
          if (_onglet == 2)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: marge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Les lieux que j ai enregistres, a cote de mes collections.
                  Plaque(
                    child: LigneFeuille(icone: 'lieu', texte: t('Lieux enregistrés'), onTap: () => context.push('/profil/lieux')),
                  ),
                  const SizedBox(height: 16),
                  _Collections(collections: Communaute.instance.mesCollections),
                ],
              ),
            )
          else if (aucune)
            Padding(
              padding: EdgeInsets.fromLTRB(marge, 24, marge, 0),
              child: Text(
                _onglet == 0 ? t('Vos photos et vos reels s’afficheront ici. Pour publier, touchez +.') : t('Vos reels s’afficheront ici. Pour en créer un, touchez +.'),
                style: Textes.discret,
                textAlign: TextAlign.center,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: MosaiquePublications(
                publications: [
                  for (final p in miennes) Publication(photo: p.photo, auteur: pseudo, appareil: p.appareil, verifiee: p.verifiee, dureeReel: p.dureeReel),
                  ...serveur,
                ],
                titre: (i) => i < n ? miennes[i].lieu.split(',').first : (serveur[i - n].lieuNom ?? ''),
                onTap: (i) => i < n ? _mienne(context, miennes[i]) : context.push('/profil/lieu/${serveur[i - n].lieu ?? '_'}/photo/${serveur[i - n].id}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mon profil sans compte : l invitation a entrer (un code par e-mail, pas de mot de passe).
class _SansCompte extends StatelessWidget {
  const _SansCompte();

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: RondVerre(icone: 'reglages', semantique: t('Réglages'), onTap: () => context.push('/profil/reglages')),
            ),
            Expanded(
              child: EtatVide(
                icone: 'profil',
                titre: t('Votre profil'),
                texte: t('Connectez-vous avec votre adresse e-mail pour publier, enregistrer des photos et suivre des créateurs. Aucun mot de passe n’est nécessaire : un code suffit.'),
                action: t('Se connecter'),
                onAction: () => context.push('/entree'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les collections : une grande photo et deux petites, comme les tableaux de Pinterest.
class _Collections extends StatelessWidget {
  const _Collections({required this.collections});

  /// Mes collections : passees par le profil, qui suit leurs changements.
  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(t('Vos collections s’afficheront ici. Enregistrez des photos et des reels pour commencer.'), style: Textes.discret, textAlign: TextAlign.center),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: [
        for (var i = 0; i < collections.length; i++)
          Appuyable(
            semantique: collections[i].nom,
            onTap: () => context.push('/profil/collection/$i'),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              optionsCollection(context, collections[i]);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: CouvertureCollection(collections[i])),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collections[i].nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              if (collections[i].secrete) ...[Icone('cadenas', taille: 14, couleur: Couleurs.discret), const SizedBox(width: 3)],
                              Flexible(
                                child: Text(
                                  tn(collections[i].nombre, '{n} publication', '{n} publications'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, color: Couleurs.discret),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Appuyable(
                      semantique: t('Plus d’options'),
                      onTap: () => optionsCollection(context, collections[i]),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 0, 6),
                        child: Icone('plus-points', taille: 20, couleur: Couleurs.discret),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// E19 : une collection.
class EcranCollection extends StatefulWidget {
  const EcranCollection({super.key, required this.index});

  final int index;

  @override
  State<EcranCollection> createState() => _EcranCollectionState();
}

class _EcranCollectionState extends State<EcranCollection> {
  /// Mes collections sur le serveur.
  List<Collection> get _liste => Communaute.instance.mesCollections;
  int get _i => widget.index.clamp(0, _liste.length - 1);

  /// Ses publications sur le serveur (nul : pas encore arrivees).
  List<Publication>? _publications;
  bool _demandees = false;

  /// Secrete et verrouillee : rien ne se charge ni ne s affiche avant l empreinte.
  bool get _verrouillee => _liste.isNotEmpty && _liste[_i].secrete && !Verrou.instance.ouvert;

  @override
  void initState() {
    super.initState();
    if (_verrouillee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _deverrouiller();
      });
    }
  }

  Future<void> _deverrouiller() async {
    if (!await Verrou.instance.ouvrir(context) && mounted) bulle(context, t('Collection verrouillée.'), icone: 'cadenas');
  }

  void _charger() {
    if (_demandees || _liste.isEmpty) return;
    _demandees = true;
    Communaute.instance.contenusDe(_liste[_i].id).then((json) {
      if (mounted && json != null) setState(() => _publications = Catalogue.instance.publicationsDepuis(json));
    });
  }

  // Renommee, rendue secrete, supprimee, reverrouillee : la page suit.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([Communaute.instance, Verrou.instance]), builder: (context, _) => _construire(context));

  Widget _construire(BuildContext context) {
    if (_liste.isEmpty) return const EcranEtat(etat: 'introuvable');
    final c = _liste[_i];
    if (_verrouillee) return _Verrouillee(nom: c.nom, onOuvrir: _deverrouiller);
    _charger();
    final publications = _publications ?? const <Publication>[];
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, haut + 8, 0, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: marge),
            child: _Haut(
              gauche: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              droite: [
                RondVerre(
                  icone: 'partager',
                  semantique: t('Partager la collection'),
                  onTap: () => feuillePartager(
                    context,
                    titre: c.nom,
                    sousTitre: '${tn(c.nombre, '{n} publication', '{n} publications')} · ${Session.instance.nomAffiche}',
                    photo: publications.firstOrNull?.photo ?? c.photos.firstOrNull ?? '',
                    lien: '$domainePublic/c/${c.id}',
                  ),
                ),
                RondVerre(
                  icone: 'plus-points',
                  semantique: t('Plus d’options'),
                  onTap: () => optionsCollection(context, c, apresSuppression: () => context.pop()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Monte(
              child: Text(
                c.nom,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.7, color: Couleurs.texte),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (c.secrete) ...[Icone('cadenas', taille: 15, couleur: Couleurs.discret), const SizedBox(width: 4)],
              Text('${c.secrete ? '${t('Secrète')} · ' : ''}${tn(c.nombre, '{n} publication', '{n} publications')}', style: TextStyle(fontSize: 14, color: Couleurs.discret)),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: MosaiquePublications(publications: publications, onTap: (i) => context.push('/profil/lieu/${publications[i].lieu ?? '_'}/photo/${publications[i].id}')),
          ),
        ],
      ),
    );
  }
}

/// Une collection secrete, verrouillee : son nom, le cadenas, et l empreinte a demander.
class _Verrouillee extends StatelessWidget {
  const _Verrouillee({required this.nom, required this.onOuvrir});

  final String nom;
  final VoidCallback onOuvrir;

  @override
  Widget build(BuildContext context) {
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(marge, MediaQuery.paddingOf(context).top + 8, marge, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
            ),
            const Spacer(),
            Icone('cadenas', taille: 40, couleur: Couleurs.discret),
            const SizedBox(height: 16),
            Text(
              nom,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Couleurs.texte),
            ),
            const SizedBox(height: 6),
            Text(t('Cette collection est secrète. Utilisez votre empreinte ou le code du téléphone pour l’ouvrir.'), textAlign: TextAlign.center, style: Textes.discret),
            const SizedBox(height: 24),
            Center(
              child: BoutonVerre(texte: t('Déverrouiller'), icone: 'cadenas', plein: true, large: false, onTap: onOuvrir),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

/// E20 : le profil d un createur.
class EcranCreateur extends StatefulWidget {
  const EcranCreateur({super.key, required this.pseudo});

  final String pseudo;

  @override
  State<EcranCreateur> createState() => _EcranCreateurState();
}

class _EcranCreateurState extends State<EcranCreateur> {
  late bool _abonne = Communaute.instance.suit(widget.pseudo);

  /// Le nombre d abonnes donne par le serveur apres mon geste (sinon calcule ici).
  int? _abonnesServeur;
  int _onglet = 0;

  Future<void> _suivre() async {
    final oui = !_abonne;
    setState(() => _abonne = oui);
    if (_serveur == null) return;
    if (!Communaute.instance.enLigne) {
      setState(() => _abonne = !oui);
      bulle(context, t('Connectez-vous pour vous abonner.'), icone: 'profil');
      return;
    }
    final n = await Communaute.instance.suivre(widget.pseudo, oui);
    if (!mounted) return;
    if (n == null) {
      setState(() => _abonne = !oui);
      bulle(context, t('Impossible de modifier l’abonnement. Réessayez.'), icone: 'alerte');
    } else if (n >= 0) {
      setState(() => _abonnesServeur = n);
    }
  }

  /// Le createur tel que le serveur le donne (nul : pas encore arrive).
  late Createur? _serveur = Catalogue.instance.createurConnu(widget.pseudo);
  bool _cherche = true;

  @override
  void initState() {
    super.initState();
    Catalogue.instance.chargerCreateur(widget.pseudo).then((c) {
      if (mounted) {
        setState(() {
          _serveur = c ?? _serveur;
          _cherche = false;
        });
      }
    });
  }

  /// Ses abonnes : le serveur (avant et apres mon geste), et mon geste en attendant.
  int _abonnes(Createur c) {
    final n = _abonnesServeur;
    if (n != null) return n;
    final depart = Communaute.instance.suit(widget.pseudo) && _serveur != null;
    return c.abonnes + (_abonne && !depart ? 1 : 0) - (!_abonne && depart ? 1 : 0);
  }

  List<Publication> _publications(Createur c) => [
    for (final p in c.publications ?? const <Publication>[])
      if (!Catalogue.instance.supprimees.contains(p.id)) p,
  ];

  void _options(Createur c) => montrerFeuille<void>(
    context,
    titre: c.nom,
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LigneFeuille(
            icone: 'partager',
            texte: t('Partager le profil'),
            onTap: () {
              Navigator.pop(f);
              _partager(c);
            },
          ),
          LigneFeuille(
            icone: 'lien',
            texte: t('Copier le lien'),
            onTap: () {
              Navigator.pop(f);
              Clipboard.setData(ClipboardData(text: 'https://$domainePublic/@${c.pseudo}'));
              bulle(context, t('Lien copié.'));
            },
          ),
          LigneFeuille(
            icone: 'bloque',
            texte: t('Bloquer {nom}', {'nom': c.nom}),
            danger: true,
            onTap: () async {
              Navigator.pop(f);
              // Sans compte : l invitation, et l on reste sur le profil.
              if (!Communaute.instance.enLigne) {
                bulle(context, t('Connectez-vous pour bloquer un compte.'), icone: 'profil');
                return;
              }
              final message = await Communaute.instance.bloquer(c.pseudo, true);
              if (!mounted) return;
              bulle(context, message ?? t('Impossible de bloquer ce compte. Réessayez.'), icone: message == null ? 'alerte' : 'bloque');
              if (message != null) {
                setState(() => _abonne = false);
                // On ne reste pas sur le profil de quelqu un qu on vient de bloquer.
                if (context.canPop()) context.pop();
              }
            },
          ),
          LigneFeuille(
            icone: 'drapeau',
            texte: t('Signaler ce profil'),
            danger: true,
            onTap: () {
              Navigator.pop(f);
              feuilleSignaler(context, quoi: 'profil', id: c.pseudo);
            },
          ),
        ],
      ),
    ),
  );

  // Partager le profil : la meme feuille que pour une photo, avec son lien.
  void _partager(Createur c) => feuillePartager(
    context,
    titre: c.nom,
    sousTitre: _serveur == null ? '@${c.pseudo}' : '@${c.pseudo} · ${tn(_abonnes(c), '{n} abonné', '{n} abonnés')}',
    photo: c.avatar ?? '',
    profil: true,
    lien: '$domainePublic/@${c.pseudo}',
  );

  @override
  Widget build(BuildContext context) {
    final trouve = _serveur;
    // Introuvable (compte supprime, ou qui m a bloque).
    if (trouve == null && !_cherche) return const EcranEtat(etat: 'introuvable');
    // Le serveur repond encore : le nom seul, le temps qu il arrive.
    final c = trouve ?? Createur(pseudo: widget.pseudo, nom: widget.pseudo, bio: '', ville: '', abonnes: 0, publications: const []);
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    final toutes = _publications(c);
    final publications = _onglet == 0 ? toutes : toutes.where((p) => p.reel).toList();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, haut + 8, 0, Mesures.hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: marge),
            child: _Haut(
              gauche: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.pop()),
              droite: [
                RondVerre(icone: 'partager', semantique: t('Partager le profil'), onTap: () => _partager(c)),
                RondVerre(icone: 'plus-points', semantique: t('Plus d’options'), onTap: () => _options(c)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 6, marge, 14),
            // Le serveur n a pas encore repondu : pas de compteur invente.
            child: _Tete(nom: c.nom, pseudo: c.pseudo, bio: c.bio, ville: c.ville, photo: c.avatar, site: c.site, abonnes: trouve == null ? null : _abonnes(c)),
          ),
          // Comme la maquette (E20) : S'abonner et Partager, cote a cote.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: marge),
                child: Row(
                  children: [
                    Expanded(
                      child: BoutonAbonner(abonne: _abonne, large: true, onTap: _suivre),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BoutonVerre(texte: t('Partager'), icone: 'partager', onTap: () => _partager(c)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (c.lifestyle > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(marge, 14, marge, 0),
              child: Plaque(
                child: LigneFeuille(icone: 'image', texte: t('Lifestyle · {n}', {'n': nombrePublications(c.lifestyle)}), onTap: () => context.push(ici(context, 'lifestyle/${c.pseudo}'))),
              ),
            ),
          const SizedBox(height: 18),
          _Onglets(noms: [t('Publications'), t('Reels')], actif: _onglet, onChange: (i) => setState(() => _onglet = i)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: MosaiquePublications(
              publications: publications,
              titre: (i) => publications[i].lieuNom ?? '',
              // Une publication s ouvre par son identifiant, dans son lieu.
              onTap: (i) => context.push(ici(context, 'lieu/${publications[i].lieu ?? '_'}/photo/${publications[i].id}')),
            ),
          ),
        ],
      ),
    );
  }
}
