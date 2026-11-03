// Les pages a lire : E35 Aide, E23 Regles communautaires, E34 Conditions
// generales, E38 Confidentialite. Une seule route, /document/:id. Ce sont des
// pages de lecture : elles defilent, le titre reste immobile.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../outils/api.dart';
import '../outils/langue.dart';
import '../theme/jetons.dart';
import '../theme/theme.dart';
import '../widgets/champ.dart';
import '../widgets/icone.dart';
import '../widgets/page.dart';
import '../widgets/verre.dart';
import 'etats.dart';
import 'reglages.dart';

class EcranDocument extends StatelessWidget {
  const EcranDocument({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => switch (id) {
    'aide' => const EcranAide(),
    'regles' => const _Regles(),
    'cgu' => const _Conditions(),
    'confidentialite' => const _Confidentialite(),
    _ => const EcranEtat(etat: 'introuvable'),
  };
}

/// L adresse du support de Discover : la seule qu on montre (aide, conditions, vie privee).
const adresseSupport = 'support@discover.simeonamoussou.com';

/// Ouvrir l e-mail vers une adresse ; sinon la dire.
Future<void> ecrireA(BuildContext context, String adresse) => _ecrire(context, adresse);

Future<void> _ecrire(BuildContext context, String adresse) async {
  final ouvert = await launchUrl(Uri(scheme: 'mailto', path: adresse));
  if (!ouvert && context.mounted) bulle(context, t('Écrivez-nous à {adresse}.', {'adresse': adresse}), icone: 'enveloppe');
}

/// La page de lecture : le retour, puis le contenu qui defile.
class _Lecture extends StatelessWidget {
  const _Lecture({required this.enfants});

  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, 40 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RondVerre(icone: 'retour', semantique: t('Retour'), onTap: () => context.canPop() ? context.pop() : context.go('/accueil')),
                ),
                const SizedBox(height: 16),
                ...enfants,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La tete d un document : la feuille de papier, le titre, la date.
class _Tete extends StatelessWidget {
  const _Tete({required this.titre, required this.sousTitre});

  final String titre;
  final String sousTitre;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(width: 44, height: 52, child: CustomPaint(painter: _Papier())),
      const SizedBox(height: 14),
      Titre(titre, style: Textes.titre),
      const SizedBox(height: 8),
      Text(sousTitre, style: Textes.discret),
      const SizedBox(height: 20),
    ],
  );
}

/// La feuille de la maquette (document-vivant) : un coin plie et des lignes
/// d ecriture, la premiere a l ocean.
class _Papier extends CustomPainter {
  const _Papier();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 48);
    final papier = Path()
      ..moveTo(8, 2.5)
      ..lineTo(25.5, 2.5)
      ..lineTo(35.5, 12.5)
      ..lineTo(35.5, 41)
      ..arcToPoint(const Offset(31, 45.5), radius: const Radius.circular(4.5))
      ..lineTo(8, 45.5)
      ..arcToPoint(const Offset(3.5, 41), radius: const Radius.circular(4.5))
      ..lineTo(3.5, 7)
      ..arcToPoint(const Offset(8, 2.5), radius: const Radius.circular(4.5))
      ..close();
    canvas.drawPath(papier, Paint()..color = Colors.white);
    final bord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeJoin = StrokeJoin.round
      ..color = Couleurs.hsl(229, 25, 60, 0.55);
    canvas.drawPath(papier, bord);
    final pli = Path()
      ..moveTo(25.5, 2.5)
      ..lineTo(25.5, 9)
      ..arcToPoint(const Offset(29, 12.5), radius: const Radius.circular(3.5), clockwise: false)
      ..lineTo(35.5, 12.5)
      ..close();
    canvas.drawPath(pli, Paint()..color = Couleurs.hsl(229, 30, 86));
    canvas.drawPath(pli, bord);
    final lignes = [(18.5, 22.5), (24.5, 30.0), (29.5, 28.0), (34.5, 30.0), (39.5, 18.0)];
    for (var i = 0; i < lignes.length; i++) {
      final (y, fin) = lignes[i];
      final trait = Path()..moveTo(9, y);
      for (var x = 9.0; x < fin; x += 4.5) {
        trait.relativeQuadraticBezierTo(1.1, -1.4, 2.25, 0);
        trait.relativeQuadraticBezierTo(1.1, 1.4, 2.25, 0);
      }
      canvas.drawPath(
        trait,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = i == 0 ? 1.9 : 1.4
          ..color = i == 0 ? Couleurs.ocean : Couleurs.hsl(229, 25, 55, 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_Papier old) => false;
}

TextStyle get _sectionTitre => const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3);

/// Un article numerote (CGU, confidentialite).
class _Article extends StatelessWidget {
  const _Article({super.key, required this.numero, required this.titre, required this.texte});

  final int numero;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Numero(numero),
            const SizedBox(width: 10),
            Expanded(
              child: Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(texte, style: Textes.corps.copyWith(height: 1.55)),
      ],
    ),
  );
}

class _Numero extends StatelessWidget {
  const _Numero(this.n, {this.couleur});

  final int n;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: couleur ?? Couleurs.texte, borderRadius: BorderRadius.circular(8)),
    child: Text(
      '$n',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Couleurs.surEncre),
    ),
  );
}

/// « Voir aussi les ... et la ... » : la phrase entiere (traduite d un bloc),
/// chaque {id} y devient un lien vers son document.
class _VoirAussi extends StatelessWidget {
  const _VoirAussi(this.phrase, this.liens);

  /// La phrase, avec {id du document} a la place de chaque lien.
  final String phrase;

  /// id du document -> texte du lien.
  final Map<String, String> liens;

  @override
  Widget build(BuildContext context) {
    final morceaux = <Widget>[];
    var debut = 0;
    for (final m in RegExp(r'\{(\w+)\}').allMatches(phrase)) {
      if (m.start > debut) morceaux.add(Text(phrase.substring(debut, m.start), style: Textes.petit));
      final id = m.group(1)!;
      morceaux.add(
        GestureDetector(
          onTap: () => context.pushReplacement('/document/$id'),
          child: Text(
            liens[id] ?? id,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Couleurs.texte, decoration: TextDecoration.underline),
          ),
        ),
      );
      debut = m.end;
    }
    if (debut < phrase.length) morceaux.add(Text(phrase.substring(debut), style: Textes.petit));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: morceaux),
    );
  }
}

// ------------------------------------------------------------ E23 regles

class _Regle {
  const _Regle(this.icone, this.titre, this.texte, [this.oui, this.non]);
  final String icone;
  final String titre;
  final String texte;
  final String? oui;
  final String? non;
}

// Les regles, dans la langue choisie (une fonction : la langue peut changer).
List<_Regle> _regles() => [
  _Regle(
    'camera',
    t('Pris sur place, par vous'),
    t('Publiez uniquement ce que vous avez photographié ou filmé vous-même, à l’endroit indiqué. Les photos anciennes sont acceptées.'),
    t('Votre photo de la plage de Fidjrossè, prise dimanche.'),
    t('Une image trouvée sur Internet ou envoyée par un ami.'),
  ),
  _Regle(
    'etincelle',
    t('Aucune image générée par IA'),
    t('Discover montre les lieux tels qu’ils sont. Les images créées ou transformées par une IA sont refusées.'),
    t('Recadrer, redresser, régler la lumière.'),
    t('Remplacer le ciel, ajouter ou effacer des éléments.'),
  ),
  _Regle(
    'carte',
    t('Des informations exactes'),
    t('Le lieu, la date et le téléphone aident les autres membres à s’y rendre. Indiquez-les tels qu’ils sont.'),
    t('« Cascade de Tanougou » pour une vidéo de Tanougou.'),
    t('Le nom d’un lieu célèbre pour obtenir plus de vues.'),
  ),
  _Regle('profil', t('Le respect des personnes'), t('Demandez l’accord d’une personne avant de la photographier de près. Les insultes, les moqueries et le harcèlement sont interdits.')),
  _Regle('bouclier', t('Les lieux sacrés et privés'), t('Respectez les lieux où la photo est interdite, comme certaines forêts sacrées. Ne montrez pas l’adresse d’un domicile.')),
  _Regle('drapeau', t('Aucun spam'), t('Les publicités déguisées, les faux comptes et les liens trompeurs sont interdits.')),
];

class _Regles extends StatelessWidget {
  const _Regles();

  @override
  Widget build(BuildContext context) => _Lecture(
    enfants: [
      _Tete(titre: t('Règles communautaires'), sousTitre: t('Six règles pour des photos fidèles à la réalité · 3 min de lecture')),
      for (final r in _regles())
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Couleurs.surface, borderRadius: BorderRadius.circular(13)),
                child: Icone(r.icone, taille: 22, couleur: Couleurs.texte),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(r.texte, style: Textes.corps.copyWith(height: 1.5)),
                    if (r.oui != null) ...[const SizedBox(height: 8), _Exemple(oui: true, texte: r.oui!), _Exemple(oui: false, texte: r.non!)],
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Text(t('Si une règle n’est pas respectée'), style: _sectionTitre),
      const SizedBox(height: 12),
      Plaque(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final (i, (titre, texte)) in [
              (t('Le contenu est retiré'), t('Vous recevez le motif et pouvez demander une seconde vérification, une seule fois.')),
              (t('Le compte peut être suspendu'), t('L’équipe peut suspendre le compte après plusieurs retraits.')),
              (t('Le compte est supprimé'), t('En cas de manquement grave ou répété.')),
            ].indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Numero(i + 1, couleur: i == 2 ? Couleurs.erreur : null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(texte, style: Textes.petit),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _VoirAussi(t('Voir aussi les {cgu} et la {confidentialite}.'), {'cgu': t('conditions générales'), 'confidentialite': t('politique de confidentialité')}),
    ],
  );
}

class _Exemple extends StatelessWidget {
  const _Exemple({required this.oui, required this.texte});

  final bool oui;
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icone(oui ? 'coche' : 'fermer', taille: 15, couleur: oui ? Couleurs.succes : Couleurs.erreur),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(texte, style: Textes.petit.copyWith(fontSize: 13.5))),
      ],
    ),
  );
}

// ------------------------------------------------------------ E34 conditions

// Les articles des conditions, dans la langue choisie.
List<(String, String)> _articlesCgu() => [
  (
    t('Objet'),
    t(
      'Les présentes conditions encadrent l’utilisation de Discover, une application de partage de photos et de reels de lieux, pris sur place par leurs auteurs. En créant un compte, vous les acceptez.',
    ),
  ),
  (
    t('Votre compte'),
    t(
      'Vous fournissez une adresse e-mail valide, à laquelle vous seul avez accès : c’est à cette adresse que vous recevez les codes de connexion. Votre compte est personnel. Vous pouvez le supprimer à tout moment depuis les réglages. Vos contenus sont alors retirés.',
    ),
  ),
  (
    t('Ce que vous publiez'),
    t(
      'Vous ne publiez que des photos et des vidéos que vous avez prises vous-même, sur le lieu indiqué. Les images générées ou retouchées par une intelligence artificielle sont refusées. Les photos anciennes sont acceptées.',
    ),
  ),
  (
    t('Les informations de capture'),
    t(
      'Discover lit dans le fichier le modèle du téléphone, la date et la position de la prise de vue. Si le fichier ne les contient pas, vous pouvez les indiquer vous-même : la publication porte alors le badge « Informations déclarées ». Une information fausse peut entraîner le retrait du contenu.',
    ),
  ),
  (
    t('Vos droits sur vos contenus'),
    t(
      'Vous restez propriétaire de vos photos et de vos reels. Vous accordez à Discover le droit de les afficher, de les redimensionner et de les convertir pour l’application, pendant toute la durée de leur publication.',
    ),
  ),
  (t('Le téléchargement des photos'), t('Les autres membres peuvent télécharger une photo en grande taille pour un usage personnel. Toute autre utilisation nécessite votre accord.')),
  (
    t('Modération et signalement'),
    t('Chaque contenu peut être signalé. L’équipe de modération examine les signalements et peut retirer un contenu ou suspendre un compte qui ne respecte pas les règles communautaires.'),
  ),
  (t('Données personnelles'), t('Discover ne collecte que les données dont l’application a besoin. Pour en savoir plus, consultez la politique de confidentialité.')),
  (t('Nous contacter'), t('Pour toute question sur ces conditions, écrivez-nous à {adresse}.', {'adresse': adresseSupport})),
];

class _Conditions extends StatefulWidget {
  const _Conditions();

  @override
  State<_Conditions> createState() => _ConditionsState();
}

class _ConditionsState extends State<_Conditions> {
  final _cles = [for (final _ in _articlesCgu()) GlobalKey()];

  void _aller(int i) {
    final cible = _cles[i].currentContext;
    if (cible != null) Scrollable.ensureVisible(cible, duration: const Duration(milliseconds: 650), curve: Courbes.signature, alignment: 0.08);
  }

  @override
  Widget build(BuildContext context) {
    final articles = _articlesCgu();
    return _Lecture(
      enfants: [
        _Tete(titre: t('Conditions générales d’utilisation'), sousTitre: t('En vigueur depuis le 22 octobre 2026 · 4 min de lecture')),
        // Le sommaire : une pastille par article, elle y fait defiler.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < articles.length; i++) ...[if (i > 0) const SizedBox(width: 8), Pastille(texte: articles[i].$1, onTap: () => _aller(i))],
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < articles.length; i++) _Article(key: _cles[i], numero: i + 1, titre: articles[i].$1, texte: articles[i].$2),
        _VoirAussi(t('Voir aussi les {regles} et la {confidentialite}.'), {'regles': t('règles communautaires'), 'confidentialite': t('politique de confidentialité')}),
      ],
    );
  }
}

// ------------------------------------------------------------ E38 confidentialite

class _Confidentialite extends StatelessWidget {
  const _Confidentialite();

  @override
  Widget build(BuildContext context) => _Lecture(
    enfants: [
      _Tete(titre: t('Politique de confidentialité'), sousTitre: t('En vigueur depuis le 22 octobre 2026 · 3 min de lecture')),
      Plaque(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('En bref'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final point in [
              t('Nous ne vendons pas vos données et n’affichons pas de publicités ciblées.'),
              t('Votre position n’est utilisée que si vous l’autorisez : pour la carte, les lieux à proximité et vos publications.'),
              t('Vous pouvez télécharger ou supprimer toutes vos données, à tout moment.'),
            ])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icone('coche', taille: 16, couleur: Couleurs.texte),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(point, style: Textes.corps.copyWith(fontSize: 14.5))),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(t('Les données que nous conservons, et pourquoi'), style: _sectionTitre),
      const SizedBox(height: 12),
      Plaque(
        child: Column(
          children: [
            for (final (i, (icone, quoi, pourquoi, duree)) in [
              ('enveloppe', t('E-mail'), t('Vous envoyer les codes de connexion'), t('Tant que le compte existe')),
              ('carte', t('Position de la prise de vue'), t('Afficher le lieu, Y aller'), t('Tant que la publication existe')),
              ('telephone', t('Modèle du téléphone, date'), t('Les informations de capture'), t('Tant que la publication existe')),
              ('image', t('Fichiers originaux'), t('Vérifier la photo (EXIF, IA)'), t('Supprimés après la vérification')),
              ('oeil', t('Vues'), t('Compter les vues. L’auteur d’une publication voit les membres qui l’ont vue'), t('Tant que la publication existe')),
              ('drapeau', t('Signalements'), t('La modération'), t('Supprimés après 1 an')),
            ].indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 0.7, indent: 52, color: Couleurs.filet),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Icone(icone, taille: 22, couleur: Couleurs.texte),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(quoi, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(pourquoi, style: Textes.petit),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: Text(duree, textAlign: TextAlign.end, style: Textes.petit.copyWith(fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
      for (final (i, (titre, texte)) in [
        (t('Ce que les autres membres voient'), t('Votre nom, votre photo de profil, vos publications et leurs informations de capture. Une collection secrète n’est visible que par vous.')),
        (t('Les copies affichées'), t('Les versions affichées dans l’application ne contiennent aucune information du fichier. Seul le fichier d’origine, resté sur votre téléphone, les conserve.')),
        (t('Vos droits'), t('Vous pouvez consulter, corriger, télécharger ou supprimer vos données. Vous pouvez aussi saisir l’Autorité de protection des données personnelles (APDP).')),
      ].indexed)
        _Article(numero: i + 1, titre: titre, texte: texte),
      const _BoutonMesDonnees(),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: () => Api.instance.jeton == null ? bulle(context, t('Connectez-vous pour supprimer votre compte.'), icone: 'profil') : confirmerSuppressionCompte(context),
          child: Text(
            t('Supprimer mon compte'),
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Couleurs.erreur),
          ),
        ),
      ),
      Center(
        child: GestureDetector(
          onTap: () => _ecrire(context, adresseSupport),
          child: Text.rich(
            TextSpan(
              text: '${t('Une question ?')} ',
              style: Textes.petit,
              children: [
                TextSpan(
                  text: adresseSupport,
                  style: TextStyle(fontWeight: FontWeight.w600, color: Couleurs.texte, decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ------------------------------------------------------------ E35 aide

List<(String, String)> _sujets() => [
  ('camera', t('Publier')),
  ('verifie', t('Capture vérifiée')),
  ('y-aller', t('Y aller')),
  ('profil', t('Compte et connexion')),
  ('telecharger', t('Envois et données')),
  ('bouclier', t('Sécurité')),
];

/// Les questions : la question, la réponse, le sujet, et des mots qu'on tape sans qu'ils
/// soient dans le texte (« mdp », « supprimer »…). Les mots restent en francais : ils
/// s ajoutent au texte traduit.
List<(String, String, String, String)> _questions() => [
  (
    t('Comment publier une photo ou une vidéo ?'),
    t(
      'Touchez Créer, puis prenez une photo, filmez un reel ou choisissez des fichiers dans votre galerie. Vous pouvez en publier jusqu’à 10 à la fois. Discover lit le téléphone, la date et le lieu dans chaque fichier.',
    ),
    t('Publier'),
    'ajouter poster partager galerie plusieurs fichiers importer',
  ),
  (
    t('Comment raccourcir un reel ou couper son son ?'),
    t(
      'Après avoir filmé ou choisi une vidéo, touchez Couper pour choisir le début et la fin (de 1 à 60 secondes). Touchez Son pour couper le son d’origine. Les modifications s’appliquent quand vous touchez Suivant.',
    ),
    t('Publier'),
    'video montage duree longueur muet audio musique',
  ),
  (
    t('Puis-je publier une photo prise il y a longtemps ?'),
    t('Oui. Choisissez-la dans la galerie. Si le fichier n’indique pas le téléphone ou la date, renseignez-les : la photo portera le badge « Informations déclarées » et sera publiée normalement.'),
    t('Publier'),
    'ancienne vieille date galerie',
  ),
  (
    t('Pourquoi les images générées par IA sont-elles refusées ?'),
    t('Discover montre les lieux tels qu’ils sont. Une image générée ou retouchée (un ciel remplacé, par exemple) induit en erreur les personnes qui feront le trajet.'),
    t('Publier'),
    'intelligence artificielle retouche montage refus refusee',
  ),
  (
    t('Que signifie le badge « Capture vérifiée » ?'),
    t(
      'Le téléphone, la date et le lieu ont été lus dans le fichier lui-même, ou la photo a été prise depuis Discover. Si vous avez saisi ces informations vous-même, la photo porte « Informations déclarées ».',
    ),
    t('Capture vérifiée'),
    'badge verifie verification declaree',
  ),
  (
    t('Pourquoi ma photo n’a-t-elle pas le badge « Capture vérifiée » ?'),
    t(
      'Le fichier ne contenait pas toutes les informations (téléphone, date, lieu), souvent parce qu’il a été envoyé par une messagerie qui les retire. Publiez le fichier d’origine, ou prenez la photo depuis Discover.',
    ),
    t('Capture vérifiée'),
    'badge manque whatsapp exif metadonnees',
  ),
  (
    t('Comment fonctionne « Y aller » ?'),
    t(
      'Touchez Y aller sur un lieu : Discover propose les applications installées sur votre téléphone. Google Maps et Waze ouvrent l’itinéraire ; Uber, Yango, Gozem, inDrive ou Bolt permettent de commander une course. Si une application ne reçoit pas la destination, son nom est copié : collez-le dans l’application.',
    ),
    t('Y aller'),
    'itineraire trajet taxi course maps waze uber yango gozem indrive bolt moto',
  ),
  (
    t('Pourquoi ma position ne s’affiche-t-elle pas sur la carte ?'),
    t('Vérifiez que la localisation est activée sur le téléphone et que Discover y a accès : Profil, Réglages, Position. Le premier point GPS peut prendre quelques secondes à l’extérieur.'),
    t('Y aller'),
    'point bleu gps localisation carte',
  ),
  (
    t('Comment me connecter sans mot de passe ?'),
    t('Saisissez votre adresse e-mail : un code à 6 chiffres, valable 10 minutes, vous est envoyé. Il ouvre votre compte, ou le crée. Vous pouvez aussi vous connecter avec Google.'),
    t('Compte et connexion'),
    'mot de passe mdp code connexion inscription google',
  ),
  (t('Je ne reçois pas le code'), t('Vérifiez le dossier Spam ou Promotions, puis touchez « Renvoyer le code » au bout d’une minute.'), t('Compte et connexion'), 'email mail recu spam courrier'),
  (
    t('Comment modifier mon adresse e-mail ?'),
    t(
      'Profil, Réglages, E-mail et connexion, puis Modifier. Confirmez avec le verrouillage de votre téléphone, puis saisissez le code envoyé à la nouvelle adresse. Votre ancienne adresse reçoit une notification. Un compte Google garde l’adresse de Google.',
    ),
    t('Compte et connexion'),
    'changer email adresse',
  ),
  (
    t('Comment supprimer mon compte ?'),
    t('Profil, Réglages, Supprimer mon compte. Le compte est supprimé définitivement au bout de 30 jours. Si vous vous reconnectez avant, la suppression est annulée.'),
    t('Compte et connexion'),
    'effacer fermer desinscrire donnees',
  ),
  (
    t('Mon envoi s’est interrompu. Que faire ?'),
    t('Vous n’avez rien à faire : l’envoi reprend automatiquement là où il s’était arrêté dès que la connexion est rétablie. Suivez sa progression depuis votre profil, dans Mes envois.'),
    t('Envois et données'),
    'envoi bloque lent reseau coupure reprise upload',
  ),
  (
    t('Comment limiter l’utilisation des données mobiles ?'),
    t(
      'Profil, Réglages, Données mobiles. Économiser les données charge des photos plus légères, Lire les reels en Wi-Fi seulement charge la vidéo quand vous touchez le reel, et Envoyer en Wi-Fi seulement met vos envois en attente du Wi-Fi. En Wi-Fi, tout se charge normalement.',
    ),
    t('Envois et données'),
    'forfait internet wifi data consommation',
  ),
  (
    t('Comment télécharger une photo ?'),
    t(
      'Touchez la photo pour l’afficher en plein écran, puis Télécharger. Elle s’enregistre dans la galerie, album Discover. Vous pouvez aussi utiliser Télécharger sur la page de la photo, et y choisir la taille.',
    ),
    t('Envois et données'),
    'enregistrer telephone galerie original haute qualite grande taille',
  ),
  (
    t('Comment signaler un contenu ou un compte ?'),
    t('Touchez « … » sur la photo ou le reel, puis Signaler. Pour un compte, ouvrez son profil, touchez « … », puis Signaler le profil. L’équipe examine chaque signalement.'),
    t('Sécurité'),
    'signalement abus arnaque faux',
  ),
  (
    t('Comment bloquer quelqu’un ?'),
    t(
      'Ouvrez son profil, touchez « … », puis Bloquer. Cette personne ne voit plus vos publications et ne peut plus vous écrire ; elle n’est pas prévenue. Retrouvez la liste dans Profil, Réglages, Comptes bloqués.',
    ),
    t('Sécurité'),
    'bloquer debloquer harcelement',
  ),
  (
    t('Comment voir moins certains contenus ?'),
    t(
      'Sur une publication, touchez Partager, puis Pas intéressé : elle disparaît de vos fils et ce créateur apparaît moins souvent. Sur un lieu de l’accueil, touchez « … », puis Voir moins de ce lieu.',
    ),
    t('Sécurité'),
    'masquer cacher pas interesse recommandation',
  ),
];

/// Sans accents ni majuscules, et les apostrophes droites : « Économiser » = « economiser ».
String _plat(String texte) {
  const de = 'àâäáãéèêëíîïóôöõúùûüçñœæ’';
  const vers = 'aaaaaeeeeiiiioooouuuucnoa\'';
  final b = StringBuffer();
  for (final c in texte.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : vers[i]);
  }
  return b.toString();
}

class EcranAide extends StatefulWidget {
  const EcranAide({super.key});

  @override
  State<EcranAide> createState() => _EcranAideState();
}

class _EcranAideState extends State<EcranAide> {
  final _recherche = TextEditingController();
  String? _sujet;
  int? _ouverte;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Chaque mot tapé doit se trouver quelque part (dans l'ordre qu'on veut).
    final mots = _plat(_recherche.text).split(RegExp(r"[^a-z0-9]+")).where((m) => m.length > 1).toList();
    // Le texte de chaque question (dans la langue choisie), aplati.
    final toutes = _questions();
    final textes = [for (final q in toutes) _plat('${q.$1} ${q.$2} ${q.$3} ${q.$4}')];
    final questions = [
      for (final (i, q) in toutes.indexed)
        if ((_sujet == null || q.$3 == _sujet) && mots.every(textes[i].contains)) (i, q),
    ];
    final cherche = mots.isNotEmpty;
    return _Lecture(
      enfants: [
        Titre(t('Comment pouvons-nous vous aider ?'), style: Textes.titre),
        const SizedBox(height: 18),
        ChampVerre(
          icone: 'loupe',
          indice: t('Rechercher dans l’aide'),
          controleur: _recherche,
          action: TextInputAction.search,
          onChanged: (_) => setState(() => _ouverte = null),
          suffixe: _recherche.text.isEmpty
              ? null
              : RondVerre(
                  icone: 'fermer',
                  semantique: t('Effacer'),
                  taille: 32,
                  onTap: () => setState(() {
                    _recherche.clear();
                    _ouverte = null;
                  }),
                ),
        ),
        if (!cherche) ...[
          const SizedBox(height: 24),
          Text(t('Sujets'), style: _sectionTitre),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              for (final (icone, texte) in _sujets())
                Appuyable(
                  semantique: texte,
                  verre: true,
                  rayonVerre: 18,
                  gonflement: 0.04,
                  onTap: () => setState(() {
                    _sujet = _sujet == texte ? null : texte;
                    _ouverte = null;
                  }),
                  child: Verre(
                    rayon: 18,
                    teinte: _sujet == texte ? TeinteVerre.retenu : TeinteVerre.clair,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icone(icone, taille: 22, couleur: Couleurs.texte),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(texte, maxLines: 2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(cherche ? tn(questions.length, '{n} résultat', '{n} résultats') : (_sujet ?? t('Questions fréquentes')), style: _sectionTitre),
        const SizedBox(height: 8),
        if (questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(t('Aucun résultat pour « {recherche} ». Essayez d’autres mots clés ou contactez l’assistance.', {'recherche': _recherche.text.trim()}), style: Textes.discret),
          ),
        for (final (i, q) in questions) _Question(question: q.$1, reponse: q.$2, ouverte: _ouverte == i, onTap: () => setState(() => _ouverte = _ouverte == i ? null : i)),
        const SizedBox(height: 20),
        Plaque(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Couleurs.surface, borderRadius: BorderRadius.circular(13)),
                child: Icone('enveloppe', taille: 22, couleur: Couleurs.texte),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('Contacter l’assistance'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(t('Réponse sous 48 h'), style: Textes.petit),
                  ],
                ),
              ),
              BoutonVerre(texte: t('Écrire'), large: false, onTap: () => _ecrire(context, adresseSupport)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Plaque(
          child: Column(
            children: [
              for (final (i, (icone, texte, id)) in [
                ('bouclier', t('Règles communautaires'), 'regles'),
                ('document', t('Conditions générales'), 'cgu'),
                ('cadenas', t('Confidentialité'), 'confidentialite'),
              ].indexed) ...[
                if (i > 0) Divider(height: 1, thickness: 0.7, indent: 52, color: Couleurs.filet),
                InkWell(
                  onTap: () => context.push('/document/$id'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      children: [
                        Icone(icone, taille: 22, couleur: Couleurs.texte),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(texte, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
                        ),
                        Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question, required this.reponse, required this.ouverte, required this.onTap});

  final String question;
  final String reponse;
  final bool ouverte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Couleurs.filet)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: ouverte,
          button: true,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(question, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.3)),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: ouverte ? 0.5 : 0,
                    duration: const Duration(milliseconds: 420),
                    curve: Courbes.ressort,
                    child: Icone('chevron-bas', taille: 18, couleur: Couleurs.discret),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Courbes.interface,
          alignment: Alignment.topCenter,
          child: ouverte
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(reponse, style: Textes.discret.copyWith(fontSize: 14.5)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );
}

/// Télécharger mes données : le serveur renvoie tout ce qu'il garde sur le compte (JSON) ; le
/// fichier s'enregistre ou se partage avec le choix d'Android.
class _BoutonMesDonnees extends StatefulWidget {
  const _BoutonMesDonnees();

  @override
  State<_BoutonMesDonnees> createState() => _BoutonMesDonneesState();
}

class _BoutonMesDonneesState extends State<_BoutonMesDonnees> {
  bool _attente = false;

  Future<void> _telecharger() async {
    if (Api.instance.jeton == null) return bulle(context, t('Connectez-vous pour télécharger vos données.'), icone: 'profil');
    setState(() => _attente = true);
    try {
      final r = await Api.instance.get('moi/donnees');
      final dossier = await getTemporaryDirectory();
      final jour = DateTime.now().toIso8601String().substring(0, 10);
      final fichier = File('${dossier.path}/discover-mes-donnees-$jour.json');
      await fichier.writeAsString(const JsonEncoder.withIndent('  ').convert(r.json));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(fichier.path, mimeType: 'application/json')],
          subject: t('Mes données Discover'),
        ),
      );
    } on ErreurApi catch (e) {
      if (mounted) bulle(context, e.message, icone: 'alerte');
    } on ApiInjoignable {
      if (mounted) bulle(context, t('Aucune connexion. Réessayez dans quelques instants.'), icone: 'hors-ligne');
    } finally {
      if (mounted) setState(() => _attente = false);
    }
  }

  @override
  Widget build(BuildContext context) => BoutonVerre(texte: t('Télécharger mes données'), icone: 'telecharger', enCours: _attente, onTap: _attente ? null : _telecharger);
}
