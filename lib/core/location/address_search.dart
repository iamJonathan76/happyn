import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Une adresse proposée par le service de géocodage, déjà découpée.
///
/// Les champs sont **neutres vis-à-vis du fournisseur** : rue, ville, province,
/// pays, code postal, coordonnées. Passer de Photon à Google Places ou Mapbox
/// un jour ne demandera donc de réécrire que ce fichier — ni la base, ni les
/// écrans, ni la migration.
class AddressSuggestion {
  final String addressLine;
  final String city;
  final String province;
  final String country;
  final String postalCode;
  final double latitude;
  final double longitude;
  final String placeId;

  const AddressSuggestion({
    required this.addressLine,
    required this.city,
    required this.province,
    required this.country,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });

  /// Ce qu'on montre dans la liste de suggestions : la rue en premier, parce
  /// que c'est ce qui distingue deux propositions voisines.
  String get title => addressLine.isEmpty ? city : addressLine;

  String get subtitle =>
      [city, province, country].where((p) => p.isNotEmpty).join(', ');

  String get full => [title, subtitle].where((p) => p.isNotEmpty).join(', ');
}

/// Recherche d'adresse via Photon (OpenStreetMap).
///
/// Gratuit, sans clé et sans compte de facturation — contrairement à Google
/// Places, qui exige une carte bancaire et dont la clé finirait extractible
/// dans l'APK. Pour des adresses civiques à Ottawa-Gatineau, la couverture
/// suffit ; Photon est plus faible sur les noms de commerces.
///
/// L'instance publique n'offre aucune garantie de service et demande un usage
/// raisonnable : d'où le délai de frappe et la limite de résultats ci-dessous.
class AddressSearch {
  static const _host = 'photon.komoot.io';

  /// Centre de la zone desservie (Ottawa). Photon pondère les résultats par la
  /// proximité de ce point : sans lui, « Bank Street » remonterait Londres
  /// avant Ottawa.
  static const _biasLat = 45.4215;
  static const _biasLon = -75.6972;

  /// Annule la requête précédente quand l'utilisateur continue de taper : sans
  /// ça, une réponse lente arrivée après une plus récente écraserait la bonne
  /// liste — le classique affichage qui « revient en arrière ».
  static int _sequence = 0;

  static Future<List<AddressSuggestion>> search(String query,
      {String lang = 'en'}) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    final seq = ++_sequence;
    final uri = Uri.https(_host, '/api', {
      'q': q,
      'limit': '6',
      'lang': lang == 'fr' ? 'fr' : 'en',
      'lat': '$_biasLat',
      'lon': '$_biasLon',
    });

    try {
      final res = await http
          .get(uri, headers: {'User-Agent': 'HAPPYN/1.0 (contact@happynevents.com)'})
          .timeout(const Duration(seconds: 8));
      if (seq != _sequence) return const []; // une frappe plus récente a gagné
      if (res.statusCode != 200) {
        debugPrint('AddressSearch: HTTP ${res.statusCode}');
        return const [];
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      final features = (body['features'] as List?) ?? const [];
      return features
          .map((f) => _parse(f as Map<String, dynamic>))
          .whereType<AddressSuggestion>()
          .toList();
    } on TimeoutException {
      debugPrint('AddressSearch: delai depasse');
      return const [];
    } catch (e) {
      debugPrint('AddressSearch: $e');
      return const [];
    }
  }

  static AddressSuggestion? _parse(Map<String, dynamic> feature) {
    final props = (feature['properties'] as Map?)?.cast<String, dynamic>();
    final geom = (feature['geometry'] as Map?)?.cast<String, dynamic>();
    final coords = (geom?['coordinates'] as List?);
    if (props == null || coords == null || coords.length < 2) return null;

    // GeoJSON ordonne [longitude, latitude] — l'inverse de l'habitude. Une
    // inversion ici placerait tous les evenements au large de la Somalie.
    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();

    final number = (props['housenumber'] as String?) ?? '';
    final street = (props['street'] as String?) ?? (props['name'] as String?) ?? '';
    final line = [number, street].where((p) => p.isNotEmpty).join(' ').trim();

    return AddressSuggestion(
      addressLine: line,
      city: (props['city'] as String?) ??
          (props['town'] as String?) ??
          (props['village'] as String?) ??
          '',
      province: (props['state'] as String?) ?? '',
      country: (props['country'] as String?) ?? '',
      postalCode: (props['postcode'] as String?) ?? '',
      latitude: lat,
      longitude: lon,
      placeId: '${props['osm_type'] ?? ''}${props['osm_id'] ?? ''}',
    );
  }
}
