import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';

/// Comment HAPPYN sait où se trouve l'utilisateur.
enum LocationMode {
  /// Rien n'a encore été choisi. On ne prétend PAS savoir : tant qu'on est
  /// ici, l'écran propose, il n'affiche pas de résultats « près de toi ».
  unset,

  /// Position réelle de l'appareil. Seul cas où une distance peut être
  /// affichée.
  gps,

  /// Ville choisie à la main. On connaît une zone, pas une position — donc
  /// aucune distance ne doit être annoncée.
  city,
}

class NearbyState {
  final LocationMode mode;
  final double? latitude;
  final double? longitude;
  final String? citySlug;
  final String? cityName;
  final double radiusKm;

  const NearbyState({
    this.mode = LocationMode.unset,
    this.latitude,
    this.longitude,
    this.citySlug,
    this.cityName,
    this.radiusKm = 25,
  });

  bool get hasPoint => latitude != null && longitude != null;

  /// Une distance n'a de sens que depuis une position réelle. Afficher
  /// « 2,3 km » à partir du centre-ville choisi à la main serait un chiffre
  /// inventé — et ça se remarque dès qu'on regarde par la fenêtre.
  bool get canShowDistance => mode == LocationMode.gps && hasPoint;
}

/// Ville proposée en repli.
class City {
  final String slug;
  final String name;
  final String province;
  final double latitude;
  final double longitude;
  final double radiusKm;

  const City({
    required this.slug,
    required this.name,
    required this.province,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  String get label => '$name, $province';
}

final citiesProvider = FutureProvider<List<City>>((ref) async {
  final data = await Supabase.instance.client
      .from('cities')
      .select()
      .order('sort_order');
  return List<Map<String, dynamic>>.from(data)
      .map((c) => City(
            slug: c['slug'] as String,
            name: c['name'] as String,
            province: c['province'] as String,
            latitude: (c['latitude'] as num).toDouble(),
            longitude: (c['longitude'] as num).toDouble(),
            radiusKm: (c['radius_km'] as num).toDouble(),
          ))
      .toList();
});

/// Choix de localisation de l'utilisateur, conservé sur l'appareil.
///
/// Volontairement **local et non synchronisé** : c'est une préférence
/// d'affichage, pas une donnée de compte. L'envoyer au serveur ferait de la
/// position une information conservée alors qu'elle n'a aucune raison de
/// l'être — la minimisation commence par ne pas collecter.
class NearbyNotifier extends StateNotifier<NearbyState> {
  NearbyNotifier() : super(const NearbyState()) {
    _restore();
  }

  // `flutter_secure_storage` plutot que `shared_preferences` : ce dernier tire
  // path_provider_foundation, qui tire objective_c, dont le script de
  // compilation echoue pour Android sur cette version de Flutter. Et
  // flutter_secure_storage est deja une dependance du projet — zero paquet
  // ajoute.
  //
  // Le chiffrement est superflu pour une preference d'affichage, mais il ne
  // coute rien ici, et une ville choisie reste une information de localisation.
  static const _store = FlutterSecureStorage();

  static const _kMode = 'nearby.mode';
  static const _kCity = 'nearby.city';
  static const _kCityName = 'nearby.cityName';
  static const _kLat = 'nearby.lat';
  static const _kLng = 'nearby.lng';
  static const _kRadius = 'nearby.radius';

  static double? _readDouble(String? raw) =>
      raw == null ? null : double.tryParse(raw);

  Future<void> _restore() async {
    try {
      final mode = await _store.read(key: _kMode);
      if (mode == 'city') {
        state = NearbyState(
          mode: LocationMode.city,
          citySlug: await _store.read(key: _kCity),
          cityName: await _store.read(key: _kCityName),
          latitude: _readDouble(await _store.read(key: _kLat)),
          longitude: _readDouble(await _store.read(key: _kLng)),
          radiusKm: _readDouble(await _store.read(key: _kRadius)) ?? 25,
        );
      } else if (mode == 'gps') {
        // On ne restaure PAS les anciennes coordonnées : elles seraient
        // périmées, et afficher une distance fausse est pire que de redemander.
        // On relit la position réelle.
        await useDeviceLocation();
      }
    } catch (e) {
      debugPrint('NearbyNotifier._restore: $e');
    }
  }

  /// Demande la permission et lit la position.
  ///
  /// Renvoie `false` si l'utilisateur refuse — et l'appelant doit alors
  /// proposer la ville, pas afficher une erreur. Un refus est une réponse
  /// valable, pas une panne.
  Future<bool> useDeviceLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      // Précision moyenne : on cherche des événements dans un rayon de
      // kilomètres, pas à situer quelqu'un à trois mètres. Demander mieux
      // consommerait de la batterie pour une donnée plus intime et inutile.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      state = NearbyState(
        mode: LocationMode.gps,
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusKm: state.radiusKm,
      );
      await _store.write(key: _kMode, value: 'gps');
      return true;
    } catch (e) {
      debugPrint('useDeviceLocation: $e');
      return false;
    }
  }

  Future<void> useCity(City city) async {
    state = NearbyState(
      mode: LocationMode.city,
      latitude: city.latitude,
      longitude: city.longitude,
      citySlug: city.slug,
      cityName: city.name,
      radiusKm: city.radiusKm,
    );
    await _store.write(key: _kMode, value: 'city');
    await _store.write(key: _kCity, value: city.slug);
    await _store.write(key: _kCityName, value: city.name);
    await _store.write(key: _kLat, value: '${city.latitude}');
    await _store.write(key: _kLng, value: '${city.longitude}');
    await _store.write(key: _kRadius, value: '${city.radiusKm}');
  }

  /// Revient à l'état initial — l'utilisateur doit pouvoir défaire son choix.
  Future<void> reset() async {
    state = const NearbyState();
    for (final k in [_kMode, _kCity, _kCityName, _kLat, _kLng, _kRadius]) {
      await _store.delete(key: k);
    }
  }
}

final nearbyProvider =
    StateNotifierProvider<NearbyNotifier, NearbyState>((ref) => NearbyNotifier());

/// Un événement proche, avec sa distance quand elle est connue.
class NearbyEvent {
  final Map<String, dynamic> event;
  final double distanceKm;
  const NearbyEvent(this.event, this.distanceKm);
}

/// Événements dans le rayon, du plus proche au plus loin.
///
/// `events_near()` ne renvoie que des identifiants et des distances : on croise
/// ensuite avec les événements que l'app a déjà le droit de lire. Un événement
/// privé ne peut donc pas apparaître ici, même par accident.
final nearbyEventsProvider =
    FutureProvider.autoDispose<List<NearbyEvent>>((ref) async {
  final near = ref.watch(nearbyProvider);
  if (!near.hasPoint) return const [];

  final data = await Supabase.instance.client.rpc('events_near', params: {
    'p_lat': near.latitude,
    'p_lng': near.longitude,
    'p_radius': near.radiusKm,
  });
  final rows = List<Map<String, dynamic>>.from(data as List);
  if (rows.isEmpty) return const [];

  final events = await ref.watch(eventsProvider.future);
  final byId = {for (final e in events) e['id'] as String: e};

  final out = <NearbyEvent>[];
  for (final row in rows) {
    final ev = byId[row['event_id'] as String];
    if (ev == null) continue; // filtré par la RLS, ou par un blocage
    out.add(NearbyEvent(ev, (row['distance_km'] as num).toDouble()));
  }
  return out;
});
