// Les « ... » de Pinterest : sous une pile de l accueil, en haut d une photo,
// sur un reel, sous une collection, ou par un appui long. Ce qui est a moi se
// partage, se renomme ou se supprime ; le reste s enregistre, se partage, se
// telecharge, se voit moins (le lieu quitte l accueil) ou se signale.
import 'package:flutter/material.dart';

import '../outils/partage.dart';
import '../donnees/catalogue.dart';
import '../donnees/communaute.dart';
import '../donnees/lieux_enregistres.dart';
import '../donnees/mes_publications.dart';
import '../donnees/modeles.dart';
import '../donnees/session.dart';
import '../donnees/telechargements.dart';
import '../outils/api.dart';
import '../theme/jetons.dart';
import 'banniere.dart';
import 'champ.dart';
import 'feuille.dart';
import 'feuilles.dart';
import 'verre.dart';
import '../outils/langue.dart';
import '../outils/verrou.dart';
import 'y_aller.dart';

export 'y_aller.dart' show yAller;

/// Ma publication : publiee d ici, ou signee de mon nom sur le serveur.
bool estAMoi(Publication p) => (p.id != null && MesPublications.instance.deContenu(p.id!) != null) || (Session.instance.connecte && p.auteur.replaceFirst('@', '') == Session.instance.nomUtilisateur);

/// Supprimer ma publication, apres confirmation. Vrai si elle est partie.
Future<bool> supprimerPublication(BuildContext context, {String? contenu, String? photo, bool reel = false}) async {
  final oui = await confirmer(
    context,
    titre: reel ? t('Supprimer ce reel ?') : t('Supprimer cette publication ?'),
    texte: reel ? t('Il disparaît de Discover, avec ses réactions et ses commentaires.') : t('Elle disparaît de Discover, avec ses réactions et ses commentaires.'),
    action: t('Supprimer'),
    icone: 'poubelle',
  );
  if (!oui || !context.mounted) return false;
  final ok = await MesPublications.instance.supprimer(contenu: contenu, photo: photo);
  if (context.mounted) {
    ok
        ? bulle(context, reel ? t('Reel supprimé.') : t('Publication supprimée.'), icone: 'poubelle')
        : bulle(context, t('Impossible de supprimer. Vérifiez votre connexion, puis réessayez.'), icone: 'hors-ligne');
  }
  return ok;
}

/// Le lieu quitte l accueil, sur ce telephone (les reglages le font revenir).
void masquerLieu(BuildContext context, Lieu lieu) {
  Catalogue.instance.masquer(lieu.id);
  bulle(context, t('Vous ne verrez plus « {lieu} » sur l’accueil. Vous pouvez le réafficher dans les réglages.', {'lieu': lieu.nom}), icone: 'oeil-barre');
}

void _telecharger(BuildContext context, Publication p, String titre) => feuilleTelecharger(
  context,
  photo: p.grande ?? p.photo,
  titre: titre,
  appareil: p.appareil,
  reel: p.reel,
  dureeSecondes: p.dureeReel ?? 0,
  contenu: p.id,
  video: p.video,
  videoHd: p.videoHd,
  tailles: p.tailles,
);

/// Toute la pile d un lieu vers la galerie, une publication apres l autre : chacune avance dans
/// sa notification et dans Mes envois ; la bulle dit combien sont arrivees.
Future<void> _telechargerCollection(BuildContext context, Lieu lieu) async {
  final messager = ScaffoldMessenger.maybeOf(context);
  bulle(context, t('Téléchargement de « {nom} »…', {'nom': lieu.nom}), icone: 'telecharger');
  await Catalogue.instance.chargerContenus(lieu.id);
  final liste = Catalogue.instance.publicationsDe(lieu).where((p) => p.id != null).toList();
  var arrivees = 0;
  for (final p in liste) {
    final video = p.reel && p.video != null;
    final d = await Telechargements.instance.lancer(
      titre: (p.titre ?? '').isNotEmpty ? p.titre! : lieu.nom,
      source: video ? p.video! : (p.grande ?? p.photo),
      vignette: p.photo,
      contenu: p.id,
      video: video,
    );
    if (d.etat == EtatTelechargement.ok) arrivees++;
  }
  if (messager == null || !messager.mounted) return;
  bulle(
    messager.context,
    arrivees == liste.length
        ? tn(arrivees, '{n} publication téléchargée, dans l’album Discover.', '{n} publications téléchargées, dans l’album Discover.')
        : t('{arrivees} publications sur {total} téléchargées. Vérifiez votre connexion, puis réessayez.', {'arrivees': arrivees, 'total': liste.length}),
    icone: arrivees == liste.length ? 'coche' : 'alerte',
  );
}

/// Les options d une pile de l accueil : un lieu, par sa photo de tete.
Future<void> optionsLieu(BuildContext context, Lieu lieu) {
  final p = Catalogue.instance.publicationsDe(lieu).firstOrNull;
  return _feuille(
    context,
    lieu.nom,
    (puis) => [
      if (p?.id != null)
        LigneFeuille(
          icone: 'enregistrer',
          texte: t('Enregistrer'),
          onTap: () => puis(() => feuilleEnregistrer(context, contenu: p!.id)),
        ),
      LigneFeuille(
        icone: 'partager',
        texte: t('Partager'),
        onTap: () => puis(
          () => feuillePartager(
            context,
            titre: lieu.nom,
            sousTitre: lieu.region.isEmpty ? nombrePublications(lieu.nombre) : '${nombrePublications(lieu.nombre)} · ${lieu.region}',
            photo: lieu.photos.firstOrNull ?? '',
            lien: '$domainePublic/l/${lieu.id}',
            contenu: p?.id,
          ),
        ),
      ),
      // Une pile de plusieurs publications : toute la collection ; une seule : son image.
      if (p != null)
        lieu.nombre > 1
            ? LigneFeuille(icone: 'telecharger', texte: t('Télécharger la collection'), onTap: () => puis(() => _telechargerCollection(context, lieu)))
            : LigneFeuille(icone: 'telecharger', texte: t('Télécharger l’image'), onTap: () => puis(() => _telecharger(context, p, lieu.nom))),
      if (lieu.situe) LigneFeuille(icone: 'y-aller', texte: t('Y aller'), onTap: () => puis(() => yAller(context, lieu))),
      LigneFeuille(icone: 'oeil-barre', texte: t('Voir moins de ce lieu'), onTap: () => puis(() => masquerLieu(context, lieu))),
      if (p?.id != null)
        LigneFeuille(
          icone: 'drapeau',
          texte: t('Signaler la photo'),
          danger: true,
          onTap: () => puis(() => feuilleSignaler(context, quoi: 'photo', id: p!.id)),
        ),
    ],
  );
}

/// Les options d une publication (une photo, un reel). `apresSuppression` : la
/// page de la publication se ferme.
Future<void> optionsPublication(BuildContext context, Publication p, {Lieu? lieu, String? titre, VoidCallback? apresSuppression}) {
  final mienne = estAMoi(p);
  final l = lieu ?? (p.lieu == null ? null : Catalogue.instance.lieu(p.lieu!));
  final nom = titre ?? p.titre ?? l?.nom ?? (p.reel ? t('Ce reel') : t('Cette photo'));
  return _feuille(
    context,
    p.reel ? t('Ce reel') : t('Cette photo'),
    (puis) => [
      if (!mienne && p.id != null)
        LigneFeuille(
          icone: 'enregistrer',
          texte: t('Enregistrer'),
          onTap: () => puis(() => feuilleEnregistrer(context, contenu: p.id)),
        ),
      if (p.id != null)
        LigneFeuille(
          icone: 'partager',
          texte: t('Partager'),
          onTap: () => puis(
            () => feuillePartager(
              context,
              titre: nom,
              sousTitre: '${p.auteur}${l == null ? '' : ' · ${l.nom}'}',
              auteur: p.nomAuteur ?? p.auteur.replaceFirst('@', ''),
              avatarAuteur: p.avatarAuteur,
              photo: p.photo,
              lien: '$domainePublic/p/${p.id}',
              contenu: p.id,
            ),
          ),
        ),
      LigneFeuille(icone: 'telecharger', texte: p.reel ? t('Télécharger le reel') : t('Télécharger l’image'), onTap: () => puis(() => _telecharger(context, p, nom))),
      if (l != null && l.situe && !l.id.startsWith('p:')) LigneFeuille(icone: 'y-aller', texte: t('Y aller'), onTap: () => puis(() => yAller(context, l))),
      if (!mienne && l != null && !l.id.startsWith('p:')) LigneFeuille(icone: 'oeil-barre', texte: t('Voir moins de ce lieu'), onTap: () => puis(() => masquerLieu(context, l))),
      // Un reel d un autre : il ne revient plus dans « Pour toi ».
      if (!mienne && p.reel && p.id != null)
        LigneFeuille(
          icone: 'oeil-barre',
          texte: t('Pas intéressé'),
          onTap: () => puis(() {
            Catalogue.instance.pasInteresse(p.id!);
            bulle(context, t('Vous verrez moins de publications de ce type.'), icone: 'oeil-barre');
          }),
        ),
      if (!mienne && p.id != null)
        LigneFeuille(
          icone: 'drapeau',
          texte: p.reel ? t('Signaler le reel') : t('Signaler la photo'),
          danger: true,
          onTap: () => puis(() => feuilleSignaler(context, quoi: p.reel ? 'reel' : 'photo', id: p.id)),
        ),
      // Ma publication : modifiable pendant 1 h apres sa mise en ligne, ensuite seulement supprimee.
      if (mienne && p.id != null && p.modifiable) LigneFeuille(icone: 'crayon', texte: t('Modifier'), onTap: () => puis(() => _modifier(context, p))),
      if (mienne)
        LigneFeuille(
          icone: 'poubelle',
          texte: p.reel ? t('Supprimer le reel') : t('Supprimer la publication'),
          danger: true,
          onTap: () => puis(() async {
            if (await supprimerPublication(context, contenu: p.id, photo: p.photo, reel: p.reel)) apresSuppression?.call();
          }),
        ),
    ],
  );
}

/// Les options de ma publication encore sur ce telephone (une pile de l accueil, mon profil).
Future<void> optionsMaPublication(BuildContext context, MaPublication p) => _feuille(
  context,
  p.estUnReel ? t('Ce reel') : t('Cette photo'),
  (puis) => [
    if (p.contenu != null)
      LigneFeuille(
        icone: 'partager',
        texte: t('Partager'),
        onTap: () => puis(
          () => feuillePartager(
            context,
            titre: p.lieu.split(',').first,
            sousTitre: '@${Session.instance.nomUtilisateur}',
            auteur: Session.instance.nomAffiche,
            avatarAuteur: Session.instance.photo ?? Session.instance.avatar,
            photo: p.photo,
            lien: '$domainePublic/p/${p.contenu}',
            contenu: p.contenu,
          ),
        ),
      ),
    LigneFeuille(
      icone: 'poubelle',
      texte: p.estUnReel ? t('Supprimer le reel') : t('Supprimer la publication'),
      danger: true,
      onTap: () => puis(() => supprimerPublication(context, contenu: p.contenu, photo: p.photo, reel: p.estUnReel)),
    ),
  ],
);

/// Les options de ma collection : la renommer, la rendre secrete ou publique,
/// la supprimer (`apresSuppression` : sa page se ferme). Secrete : l empreinte d abord.
Future<void> optionsCollection(BuildContext context, Collection c, {VoidCallback? apresSuppression}) async {
  if (c.secrete && !await Verrou.instance.ouvrir(context)) return;
  if (context.mounted) await _optionsCollection(context, c, apresSuppression: apresSuppression);
}

Future<void> _optionsCollection(BuildContext context, Collection c, {VoidCallback? apresSuppression}) => _feuille(
  context,
  c.nom,
  (puis) => [
    LigneFeuille(icone: 'crayon', texte: t('Renommer'), onTap: () => puis(() => _renommer(context, c))),
    LigneFeuille(
      icone: c.secrete ? 'oeil' : 'cadenas',
      texte: c.secrete ? t('Rendre publique') : t('Rendre secrète'),
      onTap: () => puis(() async {
        final ok = await Communaute.instance.modifierCollection(c.id, secrete: !c.secrete);
        if (!context.mounted) return;
        ok
            ? bulle(context, c.secrete ? t('La collection est publique.') : t('La collection est secrète : vous seul la voyez.'), icone: 'cadenas')
            : bulle(context, t('Impossible d’enregistrer la modification. Réessayez.'), icone: 'alerte');
      }),
    ),
    LigneFeuille(
      icone: 'poubelle',
      texte: t('Supprimer la collection'),
      danger: true,
      onTap: () => puis(() async {
        final oui = await confirmer(
          context,
          titre: t('Supprimer « {nom} » ?', {'nom': c.nom}),
          texte: t('Les publications restent sur Discover. Seule la collection est supprimée.'),
          action: t('Supprimer'),
          icone: 'poubelle',
        );
        if (!oui || !context.mounted) return;
        if (!await Communaute.instance.supprimerCollection(c.id)) {
          if (context.mounted) bulle(context, t('Impossible de supprimer la collection. Réessayez.'), icone: 'alerte');
          return;
        }
        if (!context.mounted) return;
        bulle(context, t('Collection « {nom} » supprimée.', {'nom': c.nom}), icone: 'poubelle');
        apresSuppression?.call();
      }),
    ),
  ],
);

/// Mon titre et ma legende (dans l heure qui suit la mise en ligne) : le nouveau texte s affiche
/// tout de suite ; si le serveur refuse (le delai est passe), l ancien revient et la bulle le dit.
Future<void> _modifier(BuildContext context, Publication p) async {
  final titre = TextEditingController(text: p.titre ?? '');
  final legende = TextEditingController(text: p.legende ?? '');
  await montrerFeuille<void>(
    context,
    titre: t('Modifier la publication'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChampVerre(icone: 'crayon', libelle: t('Titre'), controleur: titre, facultatif: true, autofocus: true),
          const SizedBox(height: 12),
          ChampVerre(icone: 'texte', libelle: t('Légende'), controleur: legende, facultatif: true, lignes: 3),
          const SizedBox(height: 8),
          Text(
            t('Vous pouvez modifier une publication pendant 1 heure après sa mise en ligne. Ensuite, vous pourrez seulement la supprimer.'),
            style: TextStyle(fontSize: 12.5, color: Couleurs.discret),
          ),
          const SizedBox(height: 14),
          BoutonVerre(
            texte: t('Enregistrer'),
            plein: true,
            onTap: () {
              final nouveauTitre = titre.text.trim();
              final nouvelleLegende = legende.text.trim();
              Navigator.pop(f);
              if (nouveauTitre == (p.titre ?? '') && nouvelleLegende == (p.legende ?? '')) return;
              final messager = ScaffoldMessenger.maybeOf(context);
              Catalogue.instance
                  .modifierPublication(p.id!, titre: nouveauTitre, legende: nouvelleLegende)
                  .then(
                    (_) {},
                    onError: (Object e) {
                      if (messager != null && messager.mounted) {
                        bulle(messager.context, e is ErreurApi ? e.message : t('Impossible d’enregistrer la modification. Réessayez.'), icone: 'alerte');
                      }
                    },
                  );
            },
          ),
        ],
      ),
    ),
  );
  titre.dispose();
  legende.dispose();
}

Future<void> _renommer(BuildContext context, Collection c) async {
  final champ = TextEditingController(text: c.nom);
  await montrerFeuille<void>(
    context,
    titre: t('Renommer'),
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: StatefulBuilder(
        builder: (context, maj) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChampVerre(icone: 'collection', indice: t('Nom de la collection'), controleur: champ, autofocus: true, onChanged: (_) => maj(() {})),
            const SizedBox(height: 14),
            BoutonVerre(
              texte: t('Enregistrer'),
              plein: true,
              onTap: champ.text.trim().isEmpty
                  ? null
                  : () {
                      final nom = champ.text.trim();
                      Navigator.pop(f);
                      if (nom == c.nom) return;
                      Communaute.instance.modifierCollection(c.id, nom: nom).then((ok) {
                        if (!ok && context.mounted) bulle(context, t('Impossible d’enregistrer la modification. Réessayez.'), icone: 'alerte');
                      });
                    },
            ),
          ],
        ),
      ),
    ),
  );
  champ.dispose();
}

/// Une feuille d options : chaque ligne la ferme, puis agit.
Future<void> _feuille(BuildContext context, String titre, List<Widget> Function(void Function(VoidCallback) puis) lignes) => montrerFeuille<void>(
  context,
  titre: titre,
  contenu: (f) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: lignes((action) {
        Navigator.pop(f);
        action();
      }),
    ),
  ),
);
