// La moderation (lot 6), pour l equipe seule : le serveur en decide
// (ADMIN_EMAILS) et repond 404 a tout autre compte ; elle s ouvre depuis
// « Gérer Discover ». Deux files : « A verifier » (ce que l analyse n a pas
// su trancher) et « Signalements » (les publications, puis les commentaires).
import '../outils/api.dart';
import '../outils/langue.dart';

/// Un dossier de la file : la publication et ce qui la met en doute.
class DossierModeration {
  const DossierModeration({
    required this.contenu,
    required this.photo,
    required this.titre,
    required this.auteur,
    this.avatarAuteur,
    required this.type,
    required this.raison,
    required this.depuis,
    required this.signalements,
    required this.signale,
    this.telephone,
    this.origineTelephone,
    this.origineDate,
    this.originePosition,
    this.priseLe,
    this.latitude,
    this.longitude,
    this.lieu,
    this.lieuLatitude,
    this.lieuLongitude,
    this.recours = false,
  });

  factory DossierModeration.depuis(Map<String, dynamic> j, {required bool signale}) {
    final c = (j['contenu'] as Map).cast<String, dynamic>();
    final images = (c['images'] as Map?) ?? const {};
    String? url(String k) => (images[k] as Map?)?['url'] as String?;
    final capture = (c['capture'] as Map?)?.cast<String, dynamic>();
    final lieu = (c['lieu'] as Map?)?.cast<String, dynamic>();
    final origines = (capture?['origines'] as Map?) ?? const {};
    String? origine(String k) => origines[k] is String ? origines[k] as String : null;
    return DossierModeration(
      contenu: c['id'] as String,
      photo: url('1080') ?? url('affiche') ?? url('480') ?? '',
      titre: (lieu?['nom'] as String?) ?? ((c['legende'] as String?)?.isNotEmpty == true ? c['legende'] as String : t('Sans lieu')),
      auteur: ((c['auteur'] as Map?)?['nom_utilisateur'] as String?) ?? '',
      avatarAuteur: (c['auteur'] as Map?)?['avatar'] as String?,
      type: c['type'] as String? ?? 'photo',
      raison: (j['raison'] as String?) ?? (signale ? t('Signalé') : t('À vérifier')),
      depuis: DateTime.tryParse(j['depuis'] as String? ?? '') ?? DateTime.now(),
      signalements: (j['signalements'] as num?)?.toInt() ?? 0,
      signale: signale,
      telephone: capture?['telephone'] as String?,
      origineTelephone: origine('modele'),
      origineDate: origine('date'),
      originePosition: origine('position'),
      priseLe: DateTime.tryParse(capture?['prise_le'] as String? ?? ''),
      latitude: (capture?['latitude'] as num?)?.toDouble(),
      longitude: (capture?['longitude'] as num?)?.toDouble(),
      lieu: lieu?['nom'] as String?,
      lieuLatitude: lieu?['situe'] == false ? null : (lieu?['latitude'] as num?)?.toDouble(),
      lieuLongitude: lieu?['situe'] == false ? null : (lieu?['longitude'] as num?)?.toDouble(),
      recours: j['recours'] == true,
    );
  }

  final String contenu;
  final String photo;
  final String titre;
  final String auteur;

  /// Sa photo de profil (son adresse), nulle sans photo.
  final String? avatarAuteur;
  final String type;
  final String raison;
  final DateTime depuis;
  final int signalements;

  /// Venu des signalements (deja en ligne) plutot que de la file « A verifier ».
  final bool signale;
  final String? telephone;

  /// D ou vient chaque information : exif (le fichier), appareil (l appareil photo
  /// de Discover) ou declaree (l auteur l a tapee) ; nul si le serveur ne le dit pas.
  final String? origineTelephone;
  final String? origineDate;
  final String? originePosition;
  final DateTime? priseLe;
  final double? latitude;
  final double? longitude;
  final String? lieu;

  /// La position du lieu choisi par l auteur, pour la comparer a celle de la prise.
  final double? lieuLatitude;
  final double? lieuLongitude;

  /// L auteur a demande une seconde verification apres un refus.
  final bool recours;
}

/// Un commentaire signale (file « Signalements ») : l equipe le masque ou le garde.
class CommentaireSignale {
  const CommentaireSignale({required this.id, required this.texte, required this.auteur, this.nomAuteur, this.avatar, this.creeLe});

  factory CommentaireSignale.depuis(Map<String, dynamic> j) {
    final a = (j['auteur'] as Map?) ?? const {};
    return CommentaireSignale(
      id: j['id'] as String,
      texte: j['texte'] as String? ?? '',
      auteur: a['nom_utilisateur'] as String? ?? '',
      nomAuteur: a['nom_affiche'] as String?,
      avatar: a['avatar'] as String?,
      creeLe: DateTime.tryParse(j['cree_le'] as String? ?? ''),
    );
  }

  final String id;
  final String texte;
  final String auteur;
  final String? nomAuteur;
  final String? avatar;
  final DateTime? creeLe;
}

class Moderation {
  Moderation._();
  static final instance = Moderation._();

  /// Un compte connecte : le serveur dit ensuite s il est de l equipe.
  bool get ouverte => Api.instance.jeton != null;

  /// La derniere file chargee : l ecran de decision va d un dossier au suivant.
  List<DossierModeration> dossiers = const [];
  Map<String, int> totaux = const {};

  /// Les commentaires signales, lus avec la file « Signalements ».
  List<CommentaireSignale> commentaires = const [];

  /// Ce qui attend dans « Signalements » : les publications et les commentaires.
  int get signalesEnTout => (totaux['signalements'] ?? 0) + (totaux['commentaires_signales'] ?? 0);

  Future<List<DossierModeration>?> file({bool signalements = false}) async {
    if (!ouverte) return null;
    try {
      final r = await Api.instance.get('moderation/file?file=${signalements ? 'signalements' : 'a_verifier'}');
      totaux = {for (final e in ((r.json['totaux'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()};
      dossiers = [for (final d in (r.json['data'] as List? ?? []).cast<Map>()) DossierModeration.depuis(d.cast<String, dynamic>(), signale: signalements)];
      if (signalements) commentaires = [for (final c in (r.json['commentaires'] as List? ?? []).cast<Map>()) CommentaireSignale.depuis(c.cast<String, dynamic>())];
      return dossiers;
    } catch (_) {
      return null;
    }
  }

  /// Publier ou refuser (avec son motif). Renvoie le message du serveur, ou nul en cas d echec.
  Future<String?> decider(String contenu, {required bool publier, String? motif}) async {
    try {
      final r = await Api.instance.post('moderation/contenus/$contenu/decision', {'decision': publier ? 'publier' : 'refuser', 'motif': ?motif});
      return r.json['message'] as String? ?? t('C’est fait.');
    } on ErreurApi catch (e) {
      return e.message;
    } catch (_) {
      return null;
    }
  }

  /// Les signalements ne tiennent pas : le contenu reste en ligne.
  Future<bool> classer(String contenu) async {
    try {
      await Api.instance.post('moderation/contenus/$contenu/classer', {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Un commentaire signale : le masquer (il quitte la publication) ou le garder
  /// (ses signalements sont classes). Faux si le serveur ne l a pas fait.
  Future<bool> masquerCommentaire(String id) => _commentaire(id, 'masquer');

  Future<bool> garderCommentaire(String id) => _commentaire(id, 'classer');

  Future<bool> _commentaire(String id, String action) async {
    try {
      await Api.instance.post('moderation/commentaires/${Uri.encodeComponent(id)}/$action', {});
    } catch (_) {
      return false;
    }
    commentaires = [
      for (final c in commentaires)
        if (c.id != id) c,
    ];
    final n = totaux['commentaires_signales'];
    if (n != null && n > 0) totaux = {...totaux, 'commentaires_signales': n - 1};
    return true;
  }
}
