// E17 Notifications : ce qui s est passe autour de vos photos, groupe par
// moment. Une notification pas encore lue a un fond de verre, sans point ni
// couleur. Chacune mene la ou elle parle : la photo (et ses commentaires),
// le profil, les envois, le motif d un retrait. Avec un compte : celles du
// serveur (GET /api/v1/notifications), marquees lues a l ouverture.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../donnees/communaute.dart';
import '../outils/chemins.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/feuille.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';
import 'etats.dart';

enum _Genre { personne, verifiee, declaree, envoi, retiree, equipe }

class _Notif {
  const _Notif({
    this.id,
    required this.genre,
    required this.morceaux,
    required this.quand,
    required this.date,
    this.nom,
    this.photo,
    this.nouvelle = false,
    this.abonnement = false,
    this.route,
    this.avatar,
    this.pseudo,
  });

  /// Depuis le serveur.
  factory _Notif.serveur(NotificationServeur n) {
    final quand = ilYA(n.quand);
    // Sans lieu connu (« _ »), la page de la photo le retrouve par la publication.
    // Un chemin relatif : il s ouvre sous /notifications (ici), par-dessus la liste.
    final versContenu = n.contenu == null ? null : 'lieu/${n.lieu ?? '_'}/photo/${n.contenu}';
    return switch (n.genre) {
      // Le vert seulement pour une capture verifiee ; des informations declarees ne le sont pas.
      'publiee' => _Notif(
        id: n.id,
        genre: n.badge == 'verifiee' ? _Genre.verifiee : _Genre.declaree,
        morceaux: [(n.texte, false)],
        quand: quand,
        date: n.quand,
        photo: n.photo,
        nouvelle: !n.lue,
        route: versContenu,
      ),
      // Le motif s ouvre sur son ecran, avec la publication et le recours.
      'refusee' => _Notif(
        id: n.id,
        genre: _Genre.retiree,
        morceaux: [(n.texte, false)],
        quand: quand,
        date: n.quand,
        nouvelle: !n.lue,
        route: Uri(path: '/notifications/motif', queryParameters: {'texte': n.texte, 'quand': n.quand.toIso8601String(), 'contenu': ?n.contenu, 'photo': ?n.photo, 'type': ?n.typeContenu}).toString(),
      ),
      // Un message de l equipe : signe, et son ton dit s il felicite ou avertit.
      'equipe' => _Notif(id: n.id, genre: _Genre.equipe, nom: n.ton, morceaux: [(t('L’équipe de Discover'), true), (' ${n.texte}', false)], quand: quand, date: n.quand, nouvelle: !n.lue),
      _ => _Notif(
        id: n.id,
        genre: _Genre.personne,
        nom: n.acteur ?? t('Quelqu’un'),
        avatar: n.avatar,
        pseudo: n.acteurPseudo,
        morceaux: [(n.acteur ?? t('Quelqu’un'), true), (' ${n.texte}', false)],
        quand: quand,
        date: n.quand,
        photo: n.photo,
        nouvelle: !n.lue,
        abonnement: n.genre == 'abonne',
        route: n.genre == 'abonne'
            ? (n.acteurPseudo == null ? null : 'createur/${n.acteurPseudo}')
            : versContenu == null
            ? null
            : (['commentaire', 'reponse', 'mention'].contains(n.genre) ? '$versContenu?commentaires=1' : versContenu),
      ),
    };
  }

  final String? avatar;
  final String? pseudo;

  final _Genre genre;

  /// (texte, gras)
  final List<(String, bool)> morceaux;
  final String quand;

  /// Le moment exact : il range la notification dans son groupe.
  final DateTime date;
  final String? nom;
  final String? photo;
  final bool nouvelle;
  final bool abonnement;

  /// La ou mene la notification.
  final String? route;

  /// Son identifiant sur le serveur (pour la retirer).
  final String? id;
}

class EcranNotifications extends StatefulWidget {
  const EcranNotifications({super.key});

  @override
  State<EcranNotifications> createState() => _EcranNotificationsState();
}

class _EcranNotificationsState extends State<EcranNotifications> {
  /// Celles du serveur (nul : pas encore arrivees).
  List<_Notif>? _serveur;
  bool get _avecCompte => Communaute.instance.enLigne;

  /// La page suivante (nulle : tout est la), et un chargement en cours.
  String? _suivant;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    if (_avecCompte) _charger();
  }

  // La premiere page, ou la suite (`suite`) quand on arrive en bas.
  Future<void> _charger({bool suite = false}) async {
    if (_enCours || (suite && _suivant == null)) return;
    _enCours = true;
    final r = await Communaute.instance.notifications(curseur: suite ? _suivant : null);
    _enCours = false;
    if (!mounted) return;
    if (r == null) {
      if (suite) bulle(context, t('Impossible de charger les notifications suivantes. Réessayez.'), icone: 'hors-ligne');
      return;
    }
    setState(() {
      _suivant = r.suivant;
      _serveur = [...?(suite ? _serveur : null), for (final n in r.liste) _Notif.serveur(n)];
    });
    // Vues : elles sont lues (leur fond reste le temps de cette visite).
    if (r.liste.any((n) => !n.lue)) await Communaute.instance.toutLu();
  }

  Future<bool> _supprimerSurLeServeur(_Notif n) async {
    if (await Communaute.instance.supprimerNotification(n.id!)) return true;
    if (mounted) bulle(context, t('Impossible de supprimer la notification. Réessayez.'), icone: 'alerte');
    return false;
  }

  /// Retirer une notification (appui long) : elle part de la liste quand le serveur l a prise.
  Future<bool> _retirer(_Notif n) async {
    final ok = await _supprimerSurLeServeur(n);
    if (ok && mounted) setState(() => _serveur = [...?_serveur]..remove(n));
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final serveur = _serveur ?? const <_Notif>[];
    // Le groupe se lit sur la date, pas sur le texte « 3 h » (il change avec la langue).
    final maintenant = DateTime.now();
    int jours(_Notif n) => maintenant.difference(n.date).inDays;
    final groupes = [
      (t('Aujourd’hui'), serveur.where((n) => jours(n) < 1).toList()),
      (t('Cette semaine'), serveur.where((n) => jours(n) >= 1 && jours(n) < 7).toList()),
      (t('Plus tôt'), serveur.where((n) => jours(n) >= 7).toList()),
    ];
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      // Pres du bas : les notifications plus anciennes arrivent.
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400) _charger(suite: true);
          return false;
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            Row(
              children: [
                RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/accueil')),
                const Spacer(),
                RondVerre(icone: 'reglages', semantique: t('Réglages des notifications'), onTap: () => context.push('/notifications/reglages')),
              ],
            ),
            const SizedBox(height: 14),
            Titre(t('Notifications'), style: Textes.titre),
            const SizedBox(height: 18),
            if (!_avecCompte)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EtatVide(
                  icone: 'cloche',
                  titre: t('Vos notifications'),
                  texte: t('Connectez-vous pour voir ici les réactions, les commentaires et vos nouveaux abonnés.'),
                  action: t('Se connecter'),
                  onAction: () => context.push('/entree'),
                ),
              )
            else if (_serveur != null && serveur.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(t('Aucune notification pour l’instant. Les réactions, les commentaires et vos nouveaux abonnés s’afficheront ici.'), style: Textes.discret, textAlign: TextAlign.center),
              )
            else if (_serveur == null)
              const SizedBox(height: 40)
            else
              for (final (titre, liste) in groupes)
                if (liste.isNotEmpty) ...[
                  _Groupe(titre),
                  for (final n in liste)
                    // Glisser vers la gauche (ou appui long) : la notification part.
                    n.id == null
                        ? _Ligne(n)
                        : Dismissible(
                            key: ValueKey(n.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 22),
                              child: Icone('poubelle', taille: 22, couleur: Couleurs.erreur),
                            ),
                            // Le serveur d abord : refusee, elle reste a sa place.
                            confirmDismiss: (_) => _supprimerSurLeServeur(n),
                            onDismissed: (_) => setState(() => _serveur = [...?_serveur]..remove(n)),
                            child: _Ligne(n, onRetirer: () => _retirer(n)),
                          ),
                  const SizedBox(height: 14),
                ],
            if (_serveur != null && _suivant != null)
              Center(
                child: TextButton(
                  onPressed: () => _charger(suite: true),
                  child: Text(
                    t('Afficher plus'),
                    style: TextStyle(fontWeight: FontWeight.w600, color: Couleurs.texte),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Groupe extends StatelessWidget {
  const _Groupe(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      texte,
      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
    ),
  );
}

class _Ligne extends StatefulWidget {
  const _Ligne(this.n, {this.onRetirer});

  final _Notif n;

  /// Retirer la notification (appui long) ; nul : elle ne se retire pas.
  final Future<bool> Function()? onRetirer;

  @override
  State<_Ligne> createState() => _LigneState();
}

class _LigneState extends State<_Ligne> {
  late bool _abonne = widget.n.pseudo != null && Communaute.instance.suit(widget.n.pseudo!);
  late bool _nouvelle = widget.n.nouvelle;

  // S abonner en retour : tout de suite a l ecran ; l etat d avant revient si le serveur refuse.
  Future<void> _suivre() async {
    final pseudo = widget.n.pseudo;
    if (pseudo == null) return;
    if (!Communaute.instance.enLigne) {
      bulle(context, t('Connectez-vous pour vous abonner.'), icone: 'profil');
      return;
    }
    final oui = !_abonne;
    setState(() => _abonne = oui);
    if (await Communaute.instance.suivre(pseudo, oui) == null && mounted) {
      setState(() => _abonne = !oui);
      bulle(context, oui ? t('Impossible de vous abonner. Réessayez.') : t('Impossible de vous désabonner. Réessayez.'), icone: 'alerte');
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final Widget gauche = switch (n.genre) {
      _Genre.personne => Avatar(nom: n.nom!, taille: 44, photo: n.avatar),
      _Genre.verifiee => _Rond(
        fond: Couleurs.limonade,
        child: Icone('verifie', taille: 22, couleur: Couleurs.encreLimonade),
      ),
      _Genre.declaree => _Rond(
        fond: Couleurs.surface.withValues(alpha: 0.75),
        child: Icone('alerte', taille: 22, couleur: Couleurs.discret),
      ),
      _Genre.envoi => _Rond(
        fond: Couleurs.surface.withValues(alpha: 0.75),
        child: Icone('telecharger', taille: 22, couleur: Couleurs.texte),
      ),
      _Genre.retiree => _Rond(
        fond: Couleurs.erreur.withValues(alpha: 0.12),
        child: Icone('drapeau', taille: 22, couleur: Couleurs.erreur),
      ),
      _Genre.equipe =>
        n.nom == 'avertissement'
            ? _Rond(
                fond: Couleurs.erreur.withValues(alpha: 0.12),
                child: Icone('alerte', taille: 22, couleur: Couleurs.erreur),
              )
            : _Rond(
                fond: n.nom == 'felicitations' ? Couleurs.limonade : Couleurs.surface.withValues(alpha: 0.75),
                child: n.nom == 'felicitations' ? Icone('etincelle', taille: 22, couleur: Couleurs.encreLimonade) : const LogoUsw(taille: 24),
              ),
    };
    final Widget? droite = n.abonnement
        ? BoutonAbonner(abonne: _abonne, onTap: _suivre)
        : n.genre == _Genre.retiree
        ? Text(
            t('Voir le motif'),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Couleurs.texte, decoration: TextDecoration.underline),
          )
        : n.photo != null
        ? SizedBox(width: 46, height: 58, child: PhotoArrondie(n.photo!, rayon: 10))
        : null;
    final contenu = Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          gauche,
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  for (final (morceau, gras) in n.morceaux)
                    TextSpan(
                      text: morceau,
                      style: gras ? const TextStyle(fontWeight: FontWeight.w700) : null,
                    ),
                  TextSpan(
                    // Insecable : « 3 h » ne se coupe pas en fin de ligne.
                    text: '  ${n.quand.replaceAll(' ', ' ')}',
                    style: TextStyle(fontSize: 13, color: Couleurs.discret),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 14.5, height: 1.4, color: Couleurs.texte),
            ),
          ),
          if (droite != null) ...[const SizedBox(width: 10), droite],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Appuyable(
        semantique: n.morceaux.map((m) => m.$1).join(),
        onLongPress: widget.onRetirer == null
            ? null
            : () => montrerFeuille<void>(
                context,
                titre: t('Notification'),
                contenu: (f) => Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: LigneFeuille(
                    icone: 'poubelle',
                    texte: t('Supprimer la notification'),
                    danger: true,
                    onTap: () {
                      Navigator.pop(f);
                      widget.onRetirer!();
                    },
                  ),
                ),
              ),
        onTap: n.route == null
            ? null
            : () {
                // Ouverte, elle est lue : son fond s efface au retour.
                setState(() => _nouvelle = false);
                context.push(n.route!.startsWith('/') ? n.route! : ici(context, n.route!));
              },
        // Pas encore lue : un fond de verre, sans point ni couleur.
        child: _nouvelle
            ? DecoratedBox(
                decoration: BoxDecoration(color: Couleurs.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(18)),
                child: contenu,
              )
            : contenu,
      ),
    );
  }
}

class _Rond extends StatelessWidget {
  const _Rond({required this.fond, required this.child});

  final Color fond;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
    child: child,
  );
}

/// E37 Le motif d un retrait, ouvert depuis sa notification : la publication,
/// le motif tel que l equipe l a ecrit, ce que ca change, et le recours (une
/// seconde verification, une seule fois). La notification arrive par la route.
class EcranMotif extends StatefulWidget {
  const EcranMotif({super.key});

  @override
  State<EcranMotif> createState() => _EcranMotifState();
}

class _EcranMotifState extends State<EcranMotif> {
  /// La demande est partie (ou le serveur dit qu elle n est plus possible).
  bool _fermee = false;
  bool _enCours = false;

  Future<void> _demander(String contenu) async {
    setState(() => _enCours = true);
    final (code, message) = await Communaute.instance.demanderVerification(contenu);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      // 422 : deja demandee, ou la publication n est plus refusee.
      if (code == 200 || code == 422) _fermee = true;
    });
    bulle(context, message, icone: code == 200 ? 'bouclier' : 'alerte');
  }

  @override
  Widget build(BuildContext context) {
    final q = GoRouterState.of(context).uri.queryParameters;
    final texte = q['texte'] ?? '';
    final contenu = q['contenu'];
    final photo = q['photo'];
    final reel = q['type'] == 'reel';
    final quand = DateTime.tryParse(q['quand'] ?? '');
    // Le motif suit « : » dans la notification ; sinon, toute la phrase.
    final deux = texte.indexOf(' : ');
    final motif = deux < 0 ? texte : texte.substring(deux + 3).trim();
    // Le reel est retire, la publication est retiree : une phrase entiere pour chacun.
    final String? retireLe = quand == null
        ? null
        : DateTime.now().difference(quand).inMinutes < 1
        ? (reel ? t('Retiré à l’instant') : t('Retirée à l’instant'))
        : (reel ? t('Retiré il y a {duree}', {'duree': ilYA(quand)}) : t('Retirée il y a {duree}', {'duree': ilYA(quand)}));
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(marge, 8, marge, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/notifications')),
                  Expanded(
                    child: Text(
                      reel ? t('Reel retiré') : t('Publication retirée'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 84,
                            child: photo != null
                                ? PhotoArrondie(photo, rayon: 14)
                                : DecoratedBox(
                                    decoration: BoxDecoration(color: Couleurs.photoVide, borderRadius: BorderRadius.circular(14)),
                                    child: Center(child: Icone(reel ? 'reels' : 'image', taille: 24, couleur: Couleurs.discret)),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reel ? t('Votre reel') : t('Votre publication'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                if (retireLe != null) ...[const SizedBox(height: 2), Text(retireLe, style: TextStyle(fontSize: 13.5, color: Couleurs.discret))],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Plaque(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icone('drapeau', taille: 20, couleur: Couleurs.texte),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(t('Motif'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(motif.isEmpty ? t('Aucun motif n’a été indiqué.') : motif, style: Textes.petit.copyWith(fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Plaque(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          children: [
                            _Consequence(
                              'oeil-barre',
                              reel ? t('Ce reel n’est plus visible, ni par un lien ni sur la carte.') : t('Cette publication n’est plus visible, ni par un lien ni sur la carte.'),
                            ),
                            if (contenu != null) ...[
                              const SizedBox(height: 10),
                              _Consequence(
                                'bouclier',
                                t(
                                  'Si le motif vous semble incorrect, demandez une seconde vérification. Un membre de l’équipe examinera votre publication, et vous recevrez sa décision par notification. Vous ne pouvez la demander qu’une seule fois.',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (contenu != null) ...[
                BoutonVerre(
                  texte: _fermee ? t('Vérification demandée') : t('Demander une vérification'),
                  plein: !_fermee,
                  icone: _fermee ? 'coche' : null,
                  enCours: _enCours,
                  onTap: _fermee || _enCours ? null : () => _demander(contenu),
                ),
                const SizedBox(height: 10),
              ],
              BoutonVerre(texte: t('Lire les règles'), onTap: () => context.push('/document/regles')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Consequence extends StatelessWidget {
  const _Consequence(this.icone, this.texte);

  final String icone;
  final String texte;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icone(icone, taille: 19, couleur: Couleurs.texte),
      const SizedBox(width: 10),
      Expanded(
        child: Text(texte, style: TextStyle(fontSize: 14, height: 1.35, color: Couleurs.texte)),
      ),
    ],
  );
}
