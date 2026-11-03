// Ouvrir un lieu ou une photo par son lien : le catalogue le connait deja
// (l accueil, la recherche, un reel l ont fait passer), ou on le demande au
// serveur le temps d un battement ; sinon, l etat « introuvable » (E37).
import 'package:flutter/material.dart';

import '../donnees/catalogue.dart';
import '../donnees/modeles.dart';
import '../widgets/icone.dart';
import 'etats.dart';

/// Le rang d une publication dans son lieu : un nombre (le rang lui-meme) ou son identifiant.
int rangDans(Lieu lieu, String? n) {
  final rang = int.tryParse(n ?? '');
  if (rang != null) return rang;
  final i = publicationsDe(lieu).indexWhere((p) => p.id == n);
  return i < 0 ? 0 : i;
}

class LieuAttendu extends StatefulWidget {
  const LieuAttendu({super.key, required this.id, required this.construire, this.publication});

  final String id;

  /// L identifiant d une publication a trouver dans ce lieu (pas un rang).
  final String? publication;
  final Widget Function(Lieu lieu) construire;

  @override
  State<LieuAttendu> createState() => _LieuAttenduState();
}

class _LieuAttenduState extends State<LieuAttendu> {
  Lieu? _lieu;
  bool _cherche = true;

  bool get _parIdentifiant => widget.publication != null && int.tryParse(widget.publication!) == null;

  @override
  void initState() {
    super.initState();
    _lieu = _connu();
    if (_lieu != null && (!_parIdentifiant || Catalogue.instance.publication(widget.publication!) != null)) {
      _cherche = false;
    } else {
      _chercher();
    }
  }

  Lieu? _connu() => Catalogue.instance.lieu(widget.id);

  Future<void> _chercher() async {
    // « _ » : le lieu n est pas connu, la publication le dira.
    var lieu = _lieu ?? (widget.id == '_' ? null : await Catalogue.instance.chargerLieu(widget.id));
    if (_parIdentifiant) {
      // Un premier essai manque (le reseau hesite, juste apres la connexion) : un second, avant de
      // dire que la publication n est plus la.
      final p =
          await Catalogue.instance.chargerPublication(widget.publication!) ??
          await Future<void>.delayed(const Duration(milliseconds: 800)).then((_) => Catalogue.instance.chargerPublication(widget.publication!));
      // Son lieu, s il n est pas deja connu ici (un lieu tout neuf, cree par cette publication),
      // vient du serveur ; sans lieu, ou s il ne repond pas, la publication s ouvre seule.
      if (p != null && lieu == null) {
        final idLieu = p.lieu;
        lieu = idLieu == null ? null : (Catalogue.instance.lieu(idLieu) ?? await Catalogue.instance.chargerLieu(idLieu));
        if (lieu == null || publicationsDe(lieu).every((x) => x.id != p.id)) lieu = Catalogue.instance.lieuSeul(p);
      }
    }
    if (!mounted) return;
    setState(() {
      _lieu = lieu ?? _connu();
      _cherche = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lieu = _lieu;
    if (lieu != null && !_cherche) return widget.construire(lieu);
    if (_cherche) {
      // Un fond calme et le logo qui tourne : la reponse arrive en general avant qu on le remarque.
      return Scaffold(body: Center(child: const LogoQuiTourne(taille: 34)));
    }
    return const EcranEtat(etat: 'introuvable');
  }
}
