// E21 Réglages (repris de usw_mobile) : des groupes à plat (compte, données mobiles
// pensées pour la 3G, autorisations, aide), la déconnexion et la suppression du compte.
// Repris sans le groupe « Affichage » (thème sombre, police, animations), que le socle
// ne gère pas encore, ni « Équipe » (la modération, E24, hors du MVP).
// À brancher : PATCH moi, DELETE moi et POST auth/deconnexion.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../socle/navigation/routes.dart';
import '../../../socle/session/session.dart';
import '../../../socle/theme/couleurs.dart';
import '../../../socle/theme/mesures.dart';
import '../../../socle/theme/textes.dart';
import '../../../socle/widgets/icone.dart';
import '../../../socle/widgets/messages.dart';
import '../../decouverte/widgets/avatar.dart';
import '../../decouverte/widgets/feuille.dart';
import '../../decouverte/widgets/jetons.dart';
import '../../decouverte/widgets/verre.dart';
import '../../publication/widgets/plaque.dart';
import '../donnees/mon_profil.dart';

/// Les préférences de données mobiles, gardées le temps de la session.
class _Preferences {
  static bool photosReduites = true;
  static bool reelsWifi = true;
  static bool envoisWifi = false;
  static bool camera = true;
  static bool notifications = true;
}

/// E21 Réglages. Voir repartition.md.
class EcranReglages extends StatefulWidget {
  const EcranReglages({super.key});

  @override
  State<EcranReglages> createState() => _EcranReglagesState();
}

class _EcranReglagesState extends State<EcranReglages> {
  // Les pages d'aide, de règles et de compte (E34, E35, E38) sont hors du MVP.
  void _bientot() => bulle(context, 'Cette page arrive bientôt.');

  // Une autorisation : on la donne ou la retire ici ; le système garde le dernier mot.
  Future<void> _autorisation(String nom, bool actuelle, ValueChanged<bool> changer) => montrerFeuille<void>(
    context,
    titre: nom,
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LigneFeuille(
            icone: 'coche',
            texte: actuelle ? 'Autorisée' : 'Autoriser',
            onTap: () {
              Navigator.pop(f);
              setState(() => changer(true));
            },
          ),
          LigneFeuille(
            icone: 'fermer',
            texte: actuelle ? 'Ne plus autoriser' : 'Ne pas autoriser',
            danger: actuelle,
            onTap: () {
              Navigator.pop(f);
              setState(() => changer(false));
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _supprimer() => montrerFeuille<void>(
    context,
    titre: 'Supprimer votre compte ?',
    contenu: (f) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vos photos, vos reels et vos collections seront effacés après 30 jours. Vous pouvez revenir avant pour tout garder.',
            style: Textes.discret,
          ),
          const SizedBox(height: 18),
          LigneFeuille(
            icone: 'poubelle',
            texte: 'Supprimer mon compte',
            danger: true,
            onTap: () async {
              Navigator.pop(f);
              await Session.instance.fermer();
              if (!mounted) return;
              context.go(Routes.entree);
              bulle(context, 'Votre compte sera supprimé dans 30 jours. Reconnectez-vous avant pour tout garder.');
            },
          ),
          LigneFeuille(icone: 'fermer', texte: 'Annuler', onTap: () => Navigator.pop(f)),
        ],
      ),
    ),
  );

  Future<void> _deconnecter() async {
    final oui = await confirmer(
      context,
      titre: 'Se déconnecter ?',
      texte: 'Vos envois en cours seront mis en pause et reprendront à la prochaine connexion.',
      action: 'Se déconnecter',
    );
    if (!oui || !mounted) return;
    await Session.instance.fermer();
    if (mounted) context.go(Routes.entree);
  }

  @override
  Widget build(BuildContext context) {
    final p = MonProfil.instance;
    final haut = MediaQuery.paddingOf(context).top;
    final marge = Mesures.margeDe(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: ListenableBuilder(
        listenable: p,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(marge, haut + 8, marge, hautOnglets + 40 + MediaQuery.paddingOf(context).bottom),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: RondVerre(
                icone: 'retour',
                semantique: 'Retour',
                onTap: () => context.canPop() ? context.pop() : context.go(Routes.profil),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(header: true, child: const Text('Réglages', style: Textes.titre)),
            const SizedBox(height: 18),
            Appuyable(
              semantique: 'Modifier le profil',
              onTap: () => context.push(Routes.modifierProfil),
              child: Plaque(
                rayon: 22,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Avatar(nom: p.nomAffiche.isEmpty ? 'U' : p.nomAffiche, taille: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nomAffiche, style: Textes.libelle.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(p.email, overflow: TextOverflow.ellipsis, style: Textes.petit.copyWith(fontSize: 13.5)),
                        ],
                      ),
                    ),
                    const Icone('chevron-droite', taille: 20, couleur: Couleurs.discret),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _Groupe(
              titre: 'Compte',
              lignes: [
                _Ligne(icone: 'crayon', texte: 'Modifier le profil', onTap: () => context.push(Routes.modifierProfil)),
                _Ligne(icone: 'cadenas', texte: 'E-mail et mot de passe', onTap: _bientot),
                _Ligne(icone: 'bloque', texte: 'Comptes bloqués', valeur: '2', onTap: _bientot),
              ],
            ),
            _Groupe(
              titre: 'Données mobiles',
              lignes: [
                _Ligne(
                  icone: 'image',
                  texte: 'Photos en qualité réduite en 3G',
                  interrupteur: _Preferences.photosReduites,
                  onChanged: (v) => setState(() => _Preferences.photosReduites = v),
                ),
                _Ligne(
                  icone: 'reels',
                  texte: 'Lire les reels en Wi-Fi seulement',
                  interrupteur: _Preferences.reelsWifi,
                  onChanged: (v) => setState(() => _Preferences.reelsWifi = v),
                ),
                _Ligne(
                  icone: 'telecharger',
                  texte: 'Envois en Wi-Fi seulement',
                  interrupteur: _Preferences.envoisWifi,
                  onChanged: (v) => setState(() => _Preferences.envoisWifi = v),
                ),
              ],
            ),
            _Groupe(
              titre: 'Autorisations',
              lignes: [
                _Ligne(
                  icone: 'cible',
                  texte: 'Position',
                  valeur: p.position ? 'Autorisée' : 'Refusée',
                  onTap: () => _autorisation('Position', p.position, (v) => p.position = v),
                ),
                _Ligne(
                  icone: 'camera',
                  texte: 'Caméra Discover',
                  valeur: _Preferences.camera ? 'Autorisée' : 'Refusée',
                  onTap: () => _autorisation('Caméra Discover', _Preferences.camera, (v) => _Preferences.camera = v),
                ),
                _Ligne(
                  icone: 'cloche',
                  texte: 'Notifications',
                  valeur: _Preferences.notifications ? 'Activées' : 'Désactivées',
                  onTap: () =>
                      _autorisation('Notifications', _Preferences.notifications, (v) => _Preferences.notifications = v),
                ),
              ],
            ),
            _Groupe(
              titre: 'Aide et informations',
              lignes: [
                _Ligne(icone: 'aide', texte: 'Aide', onTap: _bientot),
                _Ligne(icone: 'bouclier', texte: 'Règles communautaires', onTap: _bientot),
                _Ligne(icone: 'document', texte: 'Conditions générales', onTap: _bientot),
                _Ligne(icone: 'cadenas', texte: 'Confidentialité', onTap: _bientot),
              ],
            ),
            _Groupe(
              lignes: [_Ligne(icone: 'sortie', texte: 'Se déconnecter', danger: true, onTap: _deconnecter)],
            ),
            Center(
              child: TextButton(
                onPressed: _supprimer,
                child: Text('Supprimer mon compte', style: Textes.libelle.copyWith(color: Couleurs.erreur)),
              ),
            ),
            const SizedBox(height: 6),
            Center(child: Text('Discover 1.0 · Groupe 4, IFRI', style: Textes.petit.copyWith(fontSize: 12.5))),
          ],
        ),
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
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titre != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(titre!, style: Textes.libelle.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
          ),
        Plaque(
          rayon: 22,
          child: Column(
            children: [
              for (var i = 0; i < lignes.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 52, color: Teintes.filet),
                lignes[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.texte,
    this.valeur,
    this.onTap,
    this.interrupteur,
    this.onChanged,
    this.danger = false,
  });

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
    final ligne = Padding(
      padding: EdgeInsets.fromLTRB(16, interrupteur != null ? 6 : 14, 12, interrupteur != null ? 6 : 14),
      child: Row(
        children: [
          Icone(icone, taille: 22, couleur: couleur),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texte,
              style: Textes.corps.copyWith(fontSize: 15.5, fontWeight: FontWeight.w500, color: couleur),
            ),
          ),
          if (valeur != null) ...[
            Text(valeur!, style: Textes.petit.copyWith(fontSize: 14.5)),
            const SizedBox(width: 6),
          ],
          if (interrupteur != null)
            Switch(value: interrupteur!, activeTrackColor: Couleurs.ocean, onChanged: onChanged)
          else if (!danger)
            const Icone('chevron-droite', taille: 18, couleur: Couleurs.discret),
        ],
      ),
    );
    if (interrupteur != null) return MergeSemantics(child: ligne);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: ligne);
  }
}
