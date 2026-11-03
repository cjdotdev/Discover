// « Y aller » : les applications de ce telephone qui menent au lieu. Celles d itineraire
// (Google Maps, Waze) ouvrent le trajet ; celles de course (Uber, Gozem, Yango, inDrive,
// Bolt) s ouvrent sur la destination quand elles savent la lire, sinon le nom du lieu est
// copie pour le coller. Leurs noms et icones viennent d Android (Trajets.kt).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../donnees/modeles.dart';
import '../theme/jetons.dart';
import 'banniere.dart';
import 'feuille.dart';
import 'icone.dart';
import 'verre.dart';
import '../outils/langue.dart';

const _canal = MethodChannel('bj.usw/trajets');

/// Une application proposee : son paquet Android, sa famille, et le lien de destination
/// qu elle comprend (nul : elle s ouvre seulement, le nom du lieu est copie).
typedef _Appli = ({String paquet, bool course, String? Function(Lieu l)? lien});

String _nom(Lieu l) => Uri.encodeComponent(l.nom);

final List<_Appli> _connues = [
  (paquet: 'com.google.android.apps.maps', course: false, lien: (l) => 'google.navigation:q=${l.latitude},${l.longitude}'),
  (paquet: 'com.waze', course: false, lien: (l) => 'https://waze.com/ul?ll=${l.latitude},${l.longitude}&navigate=yes'),
  (paquet: 'com.ubercab', course: true, lien: (l) => 'uber://?action=setPickup&pickup=my_location&dropoff[latitude]=${l.latitude}&dropoff[longitude]=${l.longitude}&dropoff[nickname]=${_nom(l)}'),
  (paquet: 'com.gozem', course: true, lien: null),
  (paquet: 'com.yandex.yango', course: true, lien: (l) => 'yandextaxi://route?end-lat=${l.latitude}&end-lon=${l.longitude}'),
  (paquet: 'com.yango.lite', course: true, lien: (l) => 'yandextaxi://route?end-lat=${l.latitude}&end-lon=${l.longitude}'),
  (paquet: 'sinet.startup.inDriver', course: true, lien: null),
  (paquet: 'ee.mtakso.client', course: true, lien: null),
];

Future<void> yAller(BuildContext context, Lieu lieu) async {
  final applis = <({_Appli appli, String nom, Uint8List icone})>[];
  if (Platform.isAndroid) {
    try {
      final brut =
          await _canal.invokeListMethod<Map>('installees', {
            'paquets': [for (final a in _connues) a.paquet],
          }) ??
          const [];
      for (final m in brut) {
        final appli = _connues.firstWhere((a) => a.paquet == m['paquet']);
        applis.add((appli: appli, nom: m['nom'] as String, icone: m['icone'] as Uint8List));
      }
    } catch (_) {}
  }
  if (!context.mounted) return;
  // Aucune application connue (ou pas Android) : l itineraire de Google Maps, sur le Web au besoin.
  if (applis.isEmpty) return _itineraireWeb(context, lieu);
  await montrerFeuille<void>(
    context,
    titre: t('Y aller'),
    contenu: (_) => _Choix(lieu: lieu, applis: applis),
  );
}

Future<void> _itineraireWeb(BuildContext context, Lieu lieu) async {
  final itineraire = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${lieu.latitude},${lieu.longitude}');
  final ouvert = await launchUrl(itineraire, mode: LaunchMode.externalApplication);
  if (!ouvert && context.mounted) bulle(context, t('Impossible d’ouvrir l’itinéraire.'), icone: 'alerte');
}

class _Choix extends StatelessWidget {
  const _Choix({required this.lieu, required this.applis});

  final Lieu lieu;
  final List<({_Appli appli, String nom, Uint8List icone})> applis;

  Future<void> _ouvrir(BuildContext context, _Appli a, String nom) async {
    final messager = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    final lien = a.lien?.call(lieu);
    // Sans lien de destination, le nom du lieu attend dans le presse-papiers.
    if (lien == null) await Clipboard.setData(ClipboardData(text: lieu.nom));
    var ouvert = false;
    try {
      ouvert = await _canal.invokeMethod<bool>('ouvrir', {'paquet': a.paquet, 'lien': lien}) ?? false;
    } catch (_) {}
    if (messager == null || !messager.mounted) return;
    if (!ouvert) {
      bulle(messager.context, t('Impossible d’ouvrir {nom}.', {'nom': nom}), icone: 'alerte');
    } else if (lien == null) {
      bulle(messager.context, t('Destination copiée. Collez-la dans {nom}.', {'nom': nom}), icone: 'lien');
    }
  }

  Future<void> _autre(BuildContext context) async {
    final messager = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    var ouvert = false;
    try {
      ouvert = await _canal.invokeMethod<bool>('autre', {'lien': 'geo:${lieu.latitude},${lieu.longitude}?q=${lieu.latitude},${lieu.longitude}(${_nom(lieu)})'}) ?? false;
    } catch (_) {}
    if (!ouvert && messager != null && messager.mounted) bulle(messager.context, t('Aucune autre application ne peut ouvrir ce lieu.'), icone: 'alerte');
  }

  Widget _ligne(BuildContext context, String titre, List<Widget> enfants) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titre,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Couleurs.texte),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: enfants),
      ),
    ],
  );

  Widget _case({required String nom, required Widget icone, required VoidCallback onTap}) => SizedBox(
    width: 76,
    child: Appuyable(
      semantique: nom,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(width: 54, height: 54, child: Center(child: icone)),
          const SizedBox(height: 6),
          Text(
            nom,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: 12, height: 1.2, color: Couleurs.texte),
          ),
        ],
      ),
    ),
  );

  Widget _appli(BuildContext context, ({_Appli appli, String nom, Uint8List icone}) a) =>
      _case(nom: a.nom, icone: Image.memory(a.icone, width: 50, height: 50, gaplessPlayback: true), onTap: () => _ouvrir(context, a.appli, a.nom));

  @override
  Widget build(BuildContext context) {
    final trajet = applis.where((a) => !a.appli.course).toList();
    final course = applis.where((a) => a.appli.course).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lieu.nom,
            style: TextStyle(fontSize: 13, color: Couleurs.discret),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          _ligne(context, t('Itinéraire'), [
            for (final a in trajet) _appli(context, a),
            _case(
              nom: t('Autre application'),
              icone: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Couleurs.surface.withValues(alpha: 0.8), shape: BoxShape.circle),
                child: Icone('plus-points', taille: 24, couleur: Couleurs.texte),
              ),
              onTap: () => _autre(context),
            ),
          ]),
          if (course.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ligne(context, t('Commander une course'), [for (final a in course) _appli(context, a)]),
          ],
        ],
      ),
    );
  }
}
