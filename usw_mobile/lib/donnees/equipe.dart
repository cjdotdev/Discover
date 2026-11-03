// « Gérer Discover » : ce que l application de l equipe lit et fait sur le
// serveur (usw_api, /api/v1/admin/...). Le serveur seul decide qui en fait
// partie (ADMIN_EMAILS) : pour tout autre compte, ces adresses n existent pas.
import '../outils/api.dart';
import '../outils/langue.dart';

/// Une valeur sur la periode, et sur la periode d avant (pour l evolution).
typedef Evolution = ({int periode, int precedente});

/// Le tableau de bord : les chiffres du moment, ceux de la periode, les courbes, les tetes de liste.
class Tableau {
  Tableau.depuis(Map<String, dynamic> j)
    : jours = (j['jours'] as num).toInt(),
      maintenant = {for (final e in (j['maintenant'] as Map).entries) e.key as String: (e.value as num).toInt()},
      periode = {for (final e in (j['periode'] as Map).entries) e.key as String: (periode: ((e.value as Map)['periode'] as num).toInt(), precedente: ((e.value as Map)['precedente'] as num).toInt())},
      dates = [for (final d in ((j['courbes'] as Map)['dates'] as List)) DateTime.parse(d as String)],
      courbes = {
        for (final e in (j['courbes'] as Map).entries)
          if (e.key != 'dates') e.key as String: [for (final v in e.value as List) (v as num).toInt()],
      },
      lieux = [for (final l in (j['lieux'] as List? ?? []).cast<Map>()) (id: l['id'] as String, nom: l['nom'] as String, n: (l['n'] as num).toInt())],
      createurs = [
        for (final c in (j['createurs'] as List? ?? []).cast<Map>())
          (pseudo: c['nom_utilisateur'] as String? ?? '', nom: (c['nom_affiche'] as String?) ?? (c['nom_utilisateur'] as String? ?? ''), avatar: c['avatar'] as String?, n: (c['n'] as num).toInt()),
      ];

  final int jours;
  final Map<String, int> maintenant;
  final Map<String, Evolution> periode;
  final List<DateTime> dates;
  final Map<String, List<int>> courbes;
  final List<({String id, String nom, int n})> lieux;
  final List<({String pseudo, String nom, String? avatar, int n})> createurs;
}

/// Un membre vu par l equipe.
class MembreEquipe {
  MembreEquipe.depuis(Map<String, dynamic> j)
    : id = j['id'] as String,
      pseudo = j['nom_utilisateur'] as String? ?? '',
      nom = (j['nom_affiche'] as String?) ?? (j['nom_utilisateur'] as String? ?? ''),
      email = j['email'] as String? ?? '',
      avatar = j['avatar'] as String?,
      ville = j['ville'] as String? ?? '',
      fournisseur = j['fournisseur'] as String? ?? 'email',
      inscritLe = DateTime.tryParse(j['inscrit_le'] as String? ?? ''),
      derniereActivite = DateTime.tryParse(j['derniere_activite'] as String? ?? ''),
      enLigne = j['en_ligne'] == true,
      suspendu = j['suspendu'] == true,
      publications = (j['publications'] as num?)?.toInt() ?? 0,
      signalements = (j['signalements'] as num?)?.toInt() ?? 0,
      equipe = j['equipe'] == true,
      bio = j['bio'] as String? ?? '',
      motifSuspension = j['motif_suspension'] as String?,
      suspenduLe = DateTime.tryParse(j['suspendu_le'] as String? ?? ''),
      profilComplete = j['profil_complete'] != false,
      suppressionDemandee = j['suppression_demandee_le'] != null;

  final String id;
  final String pseudo;
  final String nom;
  final String email;
  final String? avatar;
  final String ville;
  final String fournisseur;
  final DateTime? inscritLe;
  final DateTime? derniereActivite;
  final bool enLigne;
  final bool suspendu;
  final int publications;
  final int signalements;
  final bool equipe;
  final String bio;
  final String? motifSuspension;
  final DateTime? suspenduLe;
  final bool profilComplete;
  final bool suppressionDemandee;
}

/// La fiche d un membre : tout son parcours.
class FicheMembre {
  FicheMembre.depuis(Map<String, dynamic> j)
    : membre = MembreEquipe.depuis((j['membre'] as Map).cast<String, dynamic>()),
      compteurs = {for (final e in (j['compteurs'] as Map).entries) e.key as String: (e.value as num).toInt()},
      dates = [for (final d in ((j['courbes'] as Map)['dates'] as List)) DateTime.parse(d as String)],
      actif = [for (final v in ((j['courbes'] as Map)['actif'] as List)) (v as num).toInt()],
      reactions = [for (final v in ((j['courbes'] as Map)['reactions_recues'] as List)) (v as num).toInt()],
      contenus = [for (final c in (j['contenus'] as List? ?? []).cast<Map>()) c.cast<String, dynamic>()],
      statuts = {for (final e in ((j['contenus_statuts'] as Map?) ?? const {}).entries) e.key as String: e.value as String},
      signalements = [
        for (final s in (j['signalements'] as List? ?? []).cast<Map>())
          (
            motif: s['motif'] as String? ?? '',
            precision: s['precision'] as String?,
            cible: s['cible'] as String? ?? '',
            statut: s['statut'] as String? ?? '',
            le: DateTime.tryParse(s['le'] as String? ?? ''),
          ),
      ],
      appareils = [
        for (final a in (j['appareils'] as List? ?? []).cast<Map>())
          (nom: a['nom'] as String? ?? t('Téléphone'), depuis: DateTime.tryParse(a['depuis'] as String? ?? ''), dernier: DateTime.tryParse(a['dernier_usage'] as String? ?? '')),
      ],
      messages = [
        for (final m in (j['messages'] as List? ?? []).cast<Map>())
          (ton: m['ton'] as String? ?? 'info', texte: m['texte'] as String? ?? '', le: DateTime.tryParse(m['le'] as String? ?? ''), lu: m['lu'] == true),
      ];

  MembreEquipe membre;
  final Map<String, int> compteurs;
  final List<DateTime> dates;
  final List<int> actif;
  final List<int> reactions;

  /// Ses dernieres publications, telles que le serveur les donne (lues par le catalogue).
  final List<Map<String, dynamic>> contenus;

  /// Le statut de chacune (publie, file_humaine, refuse...).
  final Map<String, String> statuts;
  final List<({String motif, String? precision, String cible, String statut, DateTime? le})> signalements;
  final List<({String nom, DateTime? depuis, DateTime? dernier})> appareils;
  final List<({String ton, String texte, DateTime? le, bool lu})> messages;
}

/// Un membre signale, et ce qu on lui reproche.
typedef MembreSignale = ({MembreEquipe membre, int signalements, Map<String, int> motifs, DateTime? depuis});

/// Une page de la recherche des membres.
typedef PageMembres = ({List<MembreEquipe> membres, int total, int page, int dernierePage});

class Equipe {
  Equipe._();
  static final instance = Equipe._();

  /// Le serveur reconnait-il ce compte comme de l equipe ? (404 sinon : faux, sans bruit.)
  Future<bool> reconnue() async {
    if (Api.instance.jeton == null) return false;
    try {
      await Api.instance.get('admin/acces');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Tableau?> tableau({int jours = 30}) async {
    try {
      return Tableau.depuis((await Api.instance.get('admin/tableau?jours=$jours')).json);
    } catch (_) {
      return null;
    }
  }

  Future<PageMembres?> membres({String q = '', String filtre = 'tous', String tri = 'recents', int page = 1}) async {
    try {
      final r = await Api.instance.get('admin/membres?q=${Uri.encodeQueryComponent(q)}&filtre=$filtre&tri=$tri&page=$page');
      return (
        membres: [for (final m in (r.json['data'] as List? ?? []).cast<Map>()) MembreEquipe.depuis(m.cast<String, dynamic>())],
        total: (r.json['total'] as num?)?.toInt() ?? 0,
        page: (r.json['page'] as num?)?.toInt() ?? page,
        dernierePage: (r.json['derniere_page'] as num?)?.toInt() ?? page,
      );
    } catch (_) {
      return null;
    }
  }

  Future<FicheMembre?> fiche(String pseudo) async {
    try {
      return FicheMembre.depuis((await Api.instance.get('admin/membres/${Uri.encodeComponent(pseudo)}')).json);
    } catch (_) {
      return null;
    }
  }

  /// Suspendre (avec son motif) ou reactiver. Le membre mis a jour, ou une erreur (son message).
  Future<(MembreEquipe?, String)> suspendre(String pseudo, {String? motif}) async {
    try {
      final chemin = 'admin/membres/${Uri.encodeComponent(pseudo)}/suspension';
      final r = motif == null ? await Api.instance.delete(chemin) : await Api.instance.post(chemin, {'motif': motif});
      return (MembreEquipe.depuis((r.json['membre'] as Map).cast<String, dynamic>()), r.json['message'] as String? ?? t('C’est fait.'));
    } on ErreurApi catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, t('Aucune connexion. Réessayez.'));
    }
  }

  /// Un message de l equipe : felicitations, avertissement ou info. Le message du serveur, ou l erreur.
  Future<(bool, String)> message(String pseudo, {required String ton, required String texte}) async {
    try {
      final r = await Api.instance.post('admin/membres/${Uri.encodeComponent(pseudo)}/message', {'ton': ton, 'texte': texte});
      return (true, r.json['message'] as String? ?? t('Message envoyé.'));
    } on ErreurApi catch (e) {
      return (false, e.message);
    } catch (_) {
      return (false, t('Aucune connexion. Réessayez.'));
    }
  }

  Future<List<MembreSignale>?> membresSignales() async {
    try {
      final r = await Api.instance.get('admin/signalements/membres');
      return [
        for (final s in (r.json['data'] as List? ?? []).cast<Map>())
          (
            membre: MembreEquipe.depuis((s['membre'] as Map).cast<String, dynamic>()),
            signalements: (s['signalements'] as num?)?.toInt() ?? 0,
            motifs: {for (final e in ((s['motifs'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()},
            depuis: DateTime.tryParse(s['depuis'] as String? ?? ''),
          ),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<bool> classerMembre(String pseudo) async {
    try {
      await Api.instance.post('admin/signalements/membres/${Uri.encodeComponent(pseudo)}/classer', {});
      return true;
    } catch (_) {
      return false;
    }
  }
}
