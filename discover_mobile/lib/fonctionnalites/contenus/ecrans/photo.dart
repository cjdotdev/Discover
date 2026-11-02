// E05 Photo (repris de usw_mobile) : la photo en grand, ce qu'on peut en faire
// (aimer, commenter, partager), la fiche de capture qui la rend vérifiable (lieu
// GPS, téléphone, date, et d'où vient chaque information), son auteur, les
// commentaires, puis d'autres lieux.
// À brancher : GET contenus/{contenu} et PUT / DELETE contenus/{contenu}/reaction.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/donnees/demo.dart';
import '../../decouverte/widgets/avatar.dart';
import '../../decouverte/widgets/feuille.dart';
import '../../decouverte/widgets/jetons.dart';
import '../../decouverte/widgets/mouvement.dart';
import '../../decouverte/widgets/photo.dart';
import '../../decouverte/widgets/verre.dart';
import '../donnees/demo.dart';
import '../widgets/visionneuse.dart';

/// E05 Photo. Voir repartition.md.
class EcranPhoto extends StatelessWidget {
  const EcranPhoto({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final publication = publicationDeId(id);
    if (publication == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
        body: const EtatMessage(icone: 'image-barre', titre: 'Photo introuvable', texte: "Cette photo n'existe plus."),
      );
    }
    return _PagePhoto(id: id, lieu: publication.$1, index: publication.$2);
  }
}

class _PagePhoto extends StatefulWidget {
  const _PagePhoto({required this.id, required this.lieu, required this.index});

  final String id;
  final Lieu lieu;
  final int index;

  @override
  State<_PagePhoto> createState() => _PagePhotoState();
}

class _PagePhotoState extends State<_PagePhoto> {
  late final Publication _publication = publicationsDe(widget.lieu)[widget.index];
  late final DetailPublication _detail = detailDe(widget.lieu, widget.index);
  late bool _aime = widget.index == 0;
  bool _abonne = false;

  int get _jaime => _detail.jaime + (_aime && widget.index != 0 ? 1 : 0) - (!_aime && widget.index == 0 ? 1 : 0);

  void _commentaires() => context.push(Routes.commentaires(widget.id));

  // Partager (E10), télécharger (E08), enregistrer (E09) et signaler (E22) sont hors
  // du MVP : leurs feuilles de usw_mobile ne sont pas reprises, un message les remplace.
  void _partager() => bulle(context, 'Le lien de la photo est copié.');

  void _telecharger() => bulle(context, "L'original sera téléchargé en entier.");

  void _options() => montrerFeuille<void>(
    context,
    titre: 'Cette photo',
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LigneFeuille(
            icone: 'enregistrer',
            texte: 'Enregistrer',
            onTap: () {
              Navigator.pop(f);
              bulle(context, 'Photo enregistrée dans vos collections.');
            },
          ),
          LigneFeuille(
            icone: 'telecharger',
            texte: "Télécharger l'original",
            onTap: () {
              Navigator.pop(f);
              _telecharger();
            },
          ),
          LigneFeuille(
            icone: 'oeil-barre',
            texte: 'Masquer cette photo',
            onTap: () {
              Navigator.pop(f);
              bulle(context, 'Vous en verrez moins comme ça.');
            },
          ),
          LigneFeuille(icone: 'drapeau', texte: 'Signaler la photo', danger: true, onTap: () => Navigator.pop(f)),
        ],
      ),
    ),
  );

  // « Y aller » ouvrait l'itinéraire dans Maps avec le paquet url_launcher, absent
  // de pubspec.yaml (le socle). Mis de côté pour le moment :
  //
  // Future<void> _yAller() async {
  //   final lieu = widget.lieu;
  //   final itineraire = Uri.parse(
  //     'https://www.google.com/maps/dir/?api=1&destination=${lieu.latitude},${lieu.longitude}',
  //   );
  //   final ouvert = await launchUrl(itineraire, mode: LaunchMode.externalApplication);
  //   if (!ouvert && mounted) bulle(context, "Maps n'a pas pu s'ouvrir.");
  // }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(taille.width);
    final ratio = ratiosPhotos[_publication.photo] ?? 0.75;
    // La photo ne prend pas plus des deux tiers de l'écran : les actions et
    // le titre restent visibles sans défiler.
    final hauteurPhoto = ((taille.width - 16) / ratio).clamp(0.0, taille.height * 0.62);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, haut + 4, 0, hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Monte(
            distance: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: hauteurPhoto,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Toucher la photo l'ouvre en plein écran, dans son format.
                      GestureDetector(
                        onTap: () => ouvrirVisionneuse(context, _publication.photo),
                        child: Semantics(
                          button: true,
                          label: 'Voir la photo en plein écran',
                          child: Photo(_publication.photo),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            RondVerre(
                              icone: 'retour',
                              semantique: 'Retour',
                              surPhoto: true,
                              encre: Couleurs.texte,
                              onTap: () => context.canPop() ? context.pop() : context.go(Routes.lieu(widget.lieu.id)),
                            ),
                            const Spacer(),
                            RondVerre(
                              icone: 'plus-points',
                              semantique: "Plus d'options",
                              surPhoto: true,
                              encre: Couleurs.texte,
                              onTap: _options,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Les actions : sur la photo, ce qu'on fait d'un geste.
          Monte(
            delai: const Duration(milliseconds: 250),
            child: Padding(
              padding: EdgeInsets.fromLTRB(marge - 8, 10, marge, 2),
              child: Row(
                children: [
                  // Les actions se resserrent si le texte est agrandi.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          _Action(
                            icone: _aime ? 'coeur-plein' : 'coeur',
                            couleur: _aime ? Couleurs.erreur : null,
                            compte: nombreCourt(_jaime),
                            semantique: _aime ? "Je n'aime plus" : "J'aime",
                            onTap: () => setState(() => _aime = !_aime),
                          ),
                          _Action(
                            icone: 'commentaire',
                            compte: '${_detail.commentaires}',
                            semantique: 'Commentaires',
                            onTap: _commentaires,
                          ),
                          _Action(icone: 'partager', semantique: 'Partager', onTap: _partager),
                          _Action(icone: 'telecharger', semantique: "Télécharger l'original", onTap: _telecharger),
                        ],
                      ),
                    ),
                  ),
                  // Le bouton « Y aller », mis de côté avec _yAller ci-dessus :
                  // const SizedBox(width: 8),
                  // BoutonVerre(
                  //   texte: 'Y aller',
                  //   plein: true,
                  //   large: false,
                  //   widgetIcone: const Icone('y-aller', taille: 20),
                  //   onTap: _yAller,
                  // ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(marge, 8, marge, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    _detail.titre,
                    style: Textes.titre.copyWith(fontSize: 24, letterSpacing: -0.48, height: 1.15),
                  ),
                ),
                const SizedBox(height: 6),
                Monte(
                  delai: const Duration(milliseconds: 450),
                  child: Text(
                    _detail.legende,
                    style: Textes.corps.copyWith(height: 1.45, color: Couleurs.texte.withValues(alpha: 0.82)),
                  ),
                ),
                const SizedBox(height: 18),
                Monte(
                  delai: const Duration(milliseconds: 550),
                  child: _Fiche(lieu: widget.lieu, publication: _publication, detail: _detail),
                ),
                const SizedBox(height: 18),
                Monte(
                  delai: const Duration(milliseconds: 650),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push(Routes.createur(_publication.auteur.replaceFirst('@', ''))),
                    child: Row(
                      children: [
                        Avatar(nom: _detail.createur),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_detail.createur, style: Textes.libelle.copyWith(fontSize: 15.5)),
                              Text('${_detail.abonnes + (_abonne ? 1 : 0)} abonnés', style: Textes.petit),
                            ],
                          ),
                        ),
                        BoutonVerre(
                          texte: _abonne ? 'Abonné' : "S'abonner",
                          large: false,
                          onTap: () => setState(() => _abonne = !_abonne),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '${_detail.commentaires} commentaires',
                  style: Textes.libelle.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _Commentaire(
                  nom: _detail.createur,
                  epingle: true,
                  texte: "Le chemin se prend à pied depuis le parking de l'hôtel, comptez dix minutes.",
                ),
                const _Commentaire(
                  nom: 'Mawuli S.',
                  texte: "On y était dimanche avec @senan.voyage, c'est exactement ça.",
                ),
                const SizedBox(height: 4),
                Appuyable(
                  semantique: 'Ajouter un commentaire',
                  onTap: _commentaires,
                  child: Verre(
                    rayon: 24,
                    child: SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ajouter un commentaire, @mentionner…',
                            style: Textes.petit.copyWith(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Plus de lieux comme celui-ci', style: Textes.sousTitre.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                _Suite(lieu: widget.lieu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icone, required this.semantique, required this.onTap, this.compte, this.couleur});

  final String icone;
  final String semantique;
  final VoidCallback onTap;
  final String? compte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Appuyable(
    semantique: semantique,
    onTap: onTap,
    child: SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icone(icone, taille: 24, couleur: couleur ?? Couleurs.texte),
            if (compte != null) ...[
              const SizedBox(width: 5),
              Text(compte!, style: Textes.libelle.copyWith(fontSize: 14, color: couleur ?? Couleurs.texte)),
            ],
          ],
        ),
      ),
    ),
  );
}

/// La fiche de capture : ce qui rend la photo vérifiable, et d'où vient
/// chaque information (le fichier, ou l'auteur).
class _Fiche extends StatelessWidget {
  const _Fiche({required this.lieu, required this.publication, required this.detail});

  final Lieu lieu;
  final Publication publication;
  final DetailPublication detail;

  @override
  Widget build(BuildContext context) {
    final origine = publication.verifiee ? 'Métadonnées du fichier' : "Indiqué par l'auteur";
    // La plaque : un fond plein un ton au-dessus de la page, des coins ronds, ni bord ni ombre.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Couleurs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Informations de capture', style: Textes.libelle.copyWith(fontSize: 15))),
                BadgeCapture(verifie: publication.verifiee, court: true),
              ],
            ),
            const SizedBox(height: 6),
            _Ligne(
              icone: 'lieu',
              titre: 'Lieu',
              valeur: '${lieu.nom}, ${lieu.region}',
              origine: publication.verifiee ? 'GPS de la prise de vue · ${detail.gps}' : "Indiqué par l'auteur",
              premiere: true,
            ),
            _Ligne(icone: 'telephone', titre: 'Téléphone', valeur: publication.appareil, origine: origine),
            _Ligne(icone: 'calendrier', titre: 'Prise le', valeur: detail.priseLe, origine: origine),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.titre,
    required this.valeur,
    required this.origine,
    this.premiere = false,
  });

  final String icone;
  final String titre;
  final String valeur;
  final String origine;
  final bool premiere;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: premiere ? null : Border(top: BorderSide(color: Teintes.filet)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icone(icone, taille: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: Textes.petit.copyWith(fontSize: 12)),
                const SizedBox(height: 1),
                Text(valeur, style: Textes.libelle.copyWith(fontSize: 15)),
                Text(origine, style: Textes.petit.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Commentaire extends StatelessWidget {
  const _Commentaire({required this.nom, required this.texte, this.epingle = false});

  final String nom;
  final String texte;
  final bool epingle;

  @override
  Widget build(BuildContext context) {
    // Les @mentions en océan.
    final morceaux = <TextSpan>[];
    texte.splitMapJoin(
      RegExp(r'@[\w.]+'),
      onMatch: (m) {
        morceaux.add(
          TextSpan(
            text: m[0],
            style: const TextStyle(fontWeight: FontWeight.w600, color: Couleurs.ocean),
          ),
        );
        return '';
      },
      onNonMatch: (t) {
        morceaux.add(TextSpan(text: t));
        return '';
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(nom: nom, taille: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (epingle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      "Épinglé par l'auteur",
                      style: Textes.petit.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: Couleurs.ocean),
                    ),
                  ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$nom ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      ...morceaux,
                    ],
                  ),
                  style: Textes.corps.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// D'autres lieux, en photos comme à l'accueil.
class _Suite extends StatelessWidget {
  const _Suite({required this.lieu});

  final Lieu lieu;

  @override
  Widget build(BuildContext context) {
    final autres = lieuxDemo.where((l) => l.id != lieu.id).take(4).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < 2; c++) ...[
          if (c > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (var i = c; i < autres.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Appuyable(
                      semantique: autres[i].nom,
                      onTap: () => context.push(Routes.lieu(autres[i].id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(aspectRatio: autres[i].ratio, child: PhotoArrondie(autres[i].photos.first)),
                          const SizedBox(height: 7),
                          Text(autres[i].nom, style: Textes.libelle.copyWith(fontSize: 13.5, height: 1.25)),
                          Text('${autres[i].nombre} photos', style: Textes.petit.copyWith(fontSize: 12)),
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
}
