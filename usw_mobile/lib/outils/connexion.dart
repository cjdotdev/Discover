// Se connecter a un serveur : l IPv4 d abord, l IPv6 ensuite. Les photos (Cloudflare) ont
// une adresse IPv6 ; sur bien des reseaux mobiles l IPv6 ne passe pas (« Network is
// unreachable »), et le client de Dart, qui ne bascule pas comme un navigateur, restait
// bloque : toutes les images manquaient (accueil, photo, partage, telechargement) pendant
// que l API (sans IPv6) repondait.
import 'dart:io';

/// Pour HttpClient.connectionFactory.
Future<ConnectionTask<Socket>> connecterIPv4DAbord(Uri adresse, String? hoteProxy, int? portProxy) async {
  final hote = hoteProxy ?? adresse.host;
  final port = portProxy ?? adresse.port;
  final trouvees = await InternetAddress.lookup(hote);
  final ip = [...trouvees.where((a) => a.type == InternetAddressType.IPv4), ...trouvees.where((a) => a.type != InternetAddressType.IPv4)];
  if (ip.isEmpty) throw SocketException('Adresse introuvable : $hote');
  // Par un proxy, ou en clair : la connexion simple ; en HTTPS : chiffree, au nom du domaine.
  if (hoteProxy != null || adresse.scheme != 'https') return Socket.startConnect(ip.first, port);
  return SecureSocket.startConnect(ip.first, port);
}
