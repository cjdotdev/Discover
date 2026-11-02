// Les données de démonstration des contenus, celles de la maquette, en attendant l'API.
// Reprises de usw_mobile (donnees/demo.dart). Les lieux et les publications viennent de la découverte.
import '../../decouverte/donnees/demo.dart';

/// Ce que la page d une photo (E05) montre en plus de la carte. Le lot 2
/// donnera GET /api/v1/publications/{id}.
class DetailPublication {
  const DetailPublication({
    required this.titre,
    required this.legende,
    required this.priseLe,
    required this.gps,
    required this.jaime,
    required this.commentaires,
    required this.createur,
    required this.abonnes,
  });

  final String titre;
  final String legende;
  final String priseLe;

  /// Les coordonnees lues dans le fichier, telles qu affichees.
  final String gps;
  final int jaime;
  final int commentaires;
  final String createur;
  final int abonnes;
}

DetailPublication detailDe(Lieu lieu, int n) {
  if (lieu.id == 'grand-popo' && n == 0) {
    return const DetailPublication(
      titre: 'Les cocotiers de Grand-Popo',
      legende: "Fin d'après-midi sur la Route des pêches, juste avant la marée haute. Le chemin de sable part derrière le dernier cocotier.",
      priseLe: '14 mars 2026, 17 h 52',
      gps: '6,2795° N, 1,8226° E',
      jaime: 2140,
      commentaires: 48,
      createur: 'Akouavi K.',
      abonnes: 1284,
    );
  }
  String coord(double v, String plus, String moins) =>
      '${v.abs().toStringAsFixed(4).replaceAll('.', ',')}° ${v >= 0 ? plus : moins}';
  return DetailPublication(
    titre: lieu.nom,
    legende: 'Prise sur place, ${lieu.region}.',
    priseLe: '${2 + n * 3} février 2026, ${9 + n} h ${((n * 7) % 60).toString().padLeft(2, '0')}',
    gps: '${coord(lieu.latitude, 'N', 'S')}, ${coord(lieu.longitude, 'E', 'O')}',
    jaime: 120 + 37 * n,
    commentaires: 3 + n,
    createur: const ['Sènan A.', 'Aïcha K.', 'Kofi D.', 'Marius B.', 'Ola P.', 'Hounkpè T.'][n % 6],
    abonnes: 310 + 45 * n,
  );
}

/// Un nombre court : 2140 -> « 2,1 k ».
String nombreCourt(int n) =>
    n < 1000 ? '$n' : '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} k';

/// Un reel (E06). Sans video de demonstration : sa couverture, qui avance
/// lentement comme un plan filme. Le lot 4 branchera la lecture HLS.
class Reel {
  const Reel({
    required this.photo,
    required this.pseudo,
    required this.nom,
    required this.legende,
    required this.appareil,
    required this.lieu,
    required this.duree,
    required this.jaime,
    required this.commentaires,
    required this.enregistres,
    required this.partages,
    this.son = "Son d'origine",
  });

  final String photo;
  final String pseudo;
  final String nom;
  final String legende;
  final String appareil;
  final String lieu;
  final int duree;
  final int jaime;
  final int commentaires;
  final int enregistres;
  final int partages;
  final String son;
}

const reelsDemo = <Reel>[
  Reel(
    photo: 'p15',
    pseudo: 'senan.voyage',
    nom: 'Sènan Voyage',
    legende: "Le bruit de la chute couvre tout. Arrivez avant 9 h, l'eau est encore fraîche et il n'y a personne.",
    appareil: 'Infinix Note 30',
    lieu: 'kota',
    duree: 31,
    jaime: 12400,
    commentaires: 326,
    enregistres: 1024,
    partages: 418,
  ),
  Reel(
    photo: 'p12',
    pseudo: 'kofi_dzi',
    nom: 'Kofi D.',
    legende: 'Marée montante à Grand-Popo, le vent du soir. Restez jusqu’au coucher du soleil.',
    appareil: 'Samsung Galaxy A55',
    lieu: 'grand-popo',
    duree: 18,
    jaime: 5300,
    commentaires: 88,
    enregistres: 402,
    partages: 96,
  ),
  Reel(
    photo: 'p62',
    pseudo: 'marius.b',
    nom: 'Marius B.',
    legende: 'Le lever du jour depuis la colline sacrée de Dassa. Quarante minutes de montée, ça vaut tout.',
    appareil: 'Tecno Camon 30',
    lieu: 'dassa',
    duree: 24,
    jaime: 3100,
    commentaires: 41,
    enregistres: 230,
    partages: 57,
  ),
  Reel(
    photo: 'p110',
    pseudo: 'aicha.k',
    nom: 'Aïcha K.',
    legende: 'Les éléphants traversent la piste vers 17 h. Gardez vos distances, restez dans le véhicule.',
    appareil: 'iPhone 13',
    lieu: 'pendjari',
    duree: 42,
    jaime: 21800,
    commentaires: 612,
    enregistres: 3300,
    partages: 1200,
  ),
];

/// Une publication à partir de son identifiant dans l'adresse (/photo/grand-popo-0) :
/// le lieu, puis le rang de la publication dans ce lieu. Nul si rien ne correspond.
(Lieu, int)? publicationDeId(String id) {
  final tiret = id.lastIndexOf('-');
  if (tiret < 0) return null;
  final lieu = lieuxDemo.where((l) => l.id == id.substring(0, tiret)).firstOrNull;
  final rang = int.tryParse(id.substring(tiret + 1));
  if (lieu == null || rang == null || rang < 0 || rang >= publicationsDe(lieu).length) return null;
  return (lieu, rang);
}

/// L'identifiant des commentaires d'un reel : « reel-kota ».
String idCommentairesReel(Reel r) => 'reel-${r.lieu}';

/// Le nombre de commentaires et l'auteur d'une photo ou d'un reel, pour l'en-tête de E07.
({int nombre, String auteur}) infosCommentaires(String id) {
  if (id.startsWith('reel-')) {
    final r = reelsDemo.where((r) => idCommentairesReel(r) == id).firstOrNull ?? reelsDemo.first;
    return (nombre: r.commentaires, auteur: r.nom);
  }
  final p = publicationDeId(id);
  final detail = p == null ? detailDe(lieuxDemo.first, 0) : detailDe(p.$1, p.$2);
  return (nombre: detail.commentaires, auteur: detail.createur);
}
