import 'package:url_launcher/url_launcher.dart';

/// Ouvre l'app de cartes du téléphone (Google Maps, Waze…) sur une adresse.
/// `geo:` laisse Android proposer les apps installées ; fallback web sinon.
/// Gratuit, aucune clé API — on passe juste l'adresse en texte.
Future<bool> openInMaps(String address) async {
  if (address.trim().isEmpty) return false;
  final q = Uri.encodeComponent(address.trim());

  // 1) Intent natif (Android) : liste des apps de cartes installées.
  final geo = Uri.parse('geo:0,0?q=$q');
  if (await canLaunchUrl(geo)) {
    return launchUrl(geo, mode: LaunchMode.externalApplication);
  }

  // 2) Fallback universel : Google Maps web (marche partout, iOS inclus).
  final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
  return launchUrl(web, mode: LaunchMode.externalApplication);
}
