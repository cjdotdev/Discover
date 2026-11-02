// E17 Notifications (repris de usw_mobile) : ce qui s'est passé autour de vos
// photos, groupé par moment. Une notification pas encore lue a un fond de verre,
// sans point ni couleur. Chacune mène là où elle parle : la photo (et ses
// commentaires), le profil, le lieu.
// À brancher : GET notifications et POST notifications/lues.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../widgets/avatar.dart';
import '../widgets/photo.dart';
import '../widgets/verre.dart';

enum _Genre { personne, verifiee, envoi, retiree }

class _Notif {
  const _Notif({
    required this.genre,
    required this.morceaux,
    required this.quand,
    this.nom,
    this.photo,
    this.nouvelle = false,
    this.abonnement = false,
    this.route,
  });

  final _Genre genre;

  /// (texte, gras)
  final List<(String, bool)> morceaux;
  final String quand;
  final String? nom;
  final String? photo;
  final bool nouvelle;
  final bool abonnement;

  /// Là où mène la notification.
  final String? route;
}

final _aujourdhui = [
  _Notif(
    genre: _Genre.personne,
    nom: 'Mawuli S.',
    morceaux: const [('Mawuli S.', true), (' a aimé votre photo.', false)],
    quand: '2 min',
    photo: 'p108',
    nouvelle: true,
    route: Routes.photo('grand-popo-0'),
  ),
  _Notif(
    genre: _Genre.personne,
    nom: 'Kofi D.',
    morceaux: const [('Kofi D.', true), (' a commenté : « Quelle lumière, à quelle heure ? »', false)],
    quand: '1 h',
    photo: 'p77',
    nouvelle: true,
    route: Routes.commentaires('ouidah-0'),
  ),
  _Notif(
    genre: _Genre.verifiee,
    morceaux: const [
      ('Votre photo ', false),
      ('Ponton de Ouidah', true),
      (' est en ligne, avec le badge Capture vérifiée.', false),
    ],
    quand: '3 h',
    photo: 'p77',
    route: Routes.photo('ouidah-0'),
  ),
  // Mes envois (E26) est hors du MVP : cette notification ne mène nulle part pour le moment.
  const _Notif(
    genre: _Genre.envoi,
    morceaux: [('Votre envoi de ', false), ('3 photos', true), (' est terminé.', false)],
    quand: '5 h',
  ),
];

final _semaine = [
  _Notif(
    genre: _Genre.personne,
    nom: 'Aïcha K.',
    morceaux: const [('Aïcha K.', true), (" s'est abonnée à vous.", false)],
    quand: '2 j',
    abonnement: true,
    route: Routes.createur('aicha.k'),
  ),
  _Notif(
    genre: _Genre.personne,
    nom: 'Hounkpè T.',
    morceaux: const [('@hounkpe', true), (' vous a mentionnée : « @akouavi.k regarde ce coucher de soleil »', false)],
    quand: '3 j',
    photo: 'p71',
    route: Routes.commentaires('aheme-3'),
  ),
  // Le motif d'un retrait (E24, E25 modération) est hors du MVP : pas d'écran à ouvrir.
  const _Notif(
    genre: _Genre.retiree,
    morceaux: [
      ('Votre reel ', false),
      ('Cascade de Kota', true),
      (' a été retiré : il contient des images générées par IA.', false),
    ],
    quand: '4 j',
  ),
  _Notif(
    genre: _Genre.personne,
    nom: 'Sènan Voyage',
    morceaux: const [('Sènan Voyage', true), (' a publié 4 photos à ', false), ('Porto-Novo', true), ('.', false)],
    quand: '6 j',
    photo: 'p57',
    route: Routes.lieu('porto-novo'),
  ),
];

/// E17 Notifications. Voir repartition.md.
class EcranNotifications extends StatelessWidget {
  const EcranNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              RondVerre(
                icone: 'retour',
                semantique: 'Retour',
                onTap: () => context.canPop() ? context.pop() : context.go(Routes.accueil),
              ),
              const Spacer(),
              RondVerre(
                icone: 'reglages',
                semantique: 'Réglages des notifications',
                onTap: () => context.push(Routes.reglages),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(header: true, child: const Text('Notifications', style: Textes.titre)),
          const SizedBox(height: 18),
          const _Groupe("Aujourd'hui"),
          for (final n in _aujourdhui) _Ligne(n),
          const SizedBox(height: 14),
          const _Groupe('Cette semaine'),
          for (final n in _semaine) _Ligne(n),
        ],
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
    child: Text(texte, style: Textes.libelle.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
  );
}

class _Ligne extends StatefulWidget {
  const _Ligne(this.n);

  final _Notif n;

  @override
  State<_Ligne> createState() => _LigneState();
}

class _LigneState extends State<_Ligne> {
  bool _abonne = false;
  late bool _nouvelle = widget.n.nouvelle;

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final Widget gauche = switch (n.genre) {
      _Genre.personne => Avatar(nom: n.nom!, taille: 44),
      _Genre.verifiee => const _Rond(
        fond: Couleurs.limonade,
        child: Icone('verifie', taille: 22, couleur: Couleurs.encreLimonade),
      ),
      _Genre.envoi => _Rond(
        fond: Couleurs.surface.withValues(alpha: 0.75),
        child: const Icone('telecharger', taille: 22, couleur: Couleurs.texte),
      ),
      _Genre.retiree => _Rond(
        fond: Couleurs.erreur.withValues(alpha: 0.12),
        child: const Icone('drapeau', taille: 22, couleur: Couleurs.erreur),
      ),
    };
    final Widget? droite = n.abonnement
        ? BoutonVerre(
            texte: _abonne ? 'Abonné' : "S'abonner",
            plein: !_abonne,
            large: false,
            onTap: () => setState(() => _abonne = !_abonne),
          )
        : n.genre == _Genre.retiree
        ? Text('Voir le motif', style: Textes.libelle.copyWith(fontSize: 13.5, decoration: TextDecoration.underline))
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
                  for (final (t, gras) in n.morceaux)
                    TextSpan(
                      text: t,
                      style: gras ? const TextStyle(fontWeight: FontWeight.w700) : null,
                    ),
                  TextSpan(
                    // Insécable : « 3 h » ne se coupe pas en fin de ligne.
                    text: '  ${n.quand.replaceAll(' ', ' ')}',
                    style: Textes.petit,
                  ),
                ],
              ),
              style: Textes.corps.copyWith(fontSize: 14.5),
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
        onTap: n.route == null
            ? null
            : () {
                // Ouverte, elle est lue : son fond s'efface au retour.
                setState(() => _nouvelle = false);
                context.push(n.route!);
              },
        // Pas encore lue : un fond de verre, sans point ni couleur.
        child: _nouvelle
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Couleurs.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                ),
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
