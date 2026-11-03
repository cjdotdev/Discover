// Ce qu est vraiment un fichier, lu dans ses premiers octets (pas dans son nom) : une photo
// (JPEG, PNG, WebP, HEIC), une video (MP4, MOV, 3GP, MKV, WebM), ou rien que Discover publie
// (un texte, un PDF...). Un .txt choisi dans la galerie partait sinon en publication, restait
// sur le telephone et n arrivait jamais.
import 'dart:io';

enum TypeMedia { photo, video }

/// Le type du fichier, nul s il n est ni une photo ni une video (ou illisible).
Future<TypeMedia?> typeDeMedia(String chemin) async {
  List<int> o = const [];
  try {
    final f = await File(chemin).open();
    try {
      o = await f.read(16);
    } finally {
      await f.close();
    }
  } catch (_) {
    return null;
  }
  bool a(int depart, List<int> attendus) => o.length >= depart + attendus.length && [for (var i = 0; i < attendus.length; i++) o[depart + i] == attendus[i]].every((x) => x);
  String texte(int depart, int n) => o.length >= depart + n ? String.fromCharCodes(o.sublist(depart, depart + n)) : '';
  if (a(0, [0xFF, 0xD8, 0xFF]) || a(0, [0x89, 0x50, 0x4E, 0x47])) return TypeMedia.photo;
  if (texte(0, 4) == 'RIFF' && texte(8, 4) == 'WEBP') return TypeMedia.photo;
  if (a(0, [0x1A, 0x45, 0xDF, 0xA3])) return TypeMedia.video;
  // Les boites ISO (« ftyp ») : HEIC et AVIF sont des photos, le reste (MP4, MOV, 3GP) des videos.
  if (texte(4, 4) == 'ftyp') {
    const photos = {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1', 'avif'};
    return photos.contains(texte(8, 4)) ? TypeMedia.photo : TypeMedia.video;
  }
  return null;
}
