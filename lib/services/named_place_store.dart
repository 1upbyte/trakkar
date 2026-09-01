import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/named_place.dart';

class NamedPlaceStore {
  NamedPlaceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'namedPlaces';
  final SharedPreferencesAsync _preferences;

  Future<List<NamedPlace>> load() async {
    final encoded = await _preferences.getStringList(_storageKey) ?? const [];
    final places = <NamedPlace>[];
    for (final value in encoded) {
      try {
        places.add(
          NamedPlace.fromJson(jsonDecode(value) as Map<String, dynamic>),
        );
      } on Object {
        // Ignore a single malformed local record instead of losing the list.
      }
    }
    return places;
  }

  Future<void> save(List<NamedPlace> places) {
    return _preferences.setStringList(
      _storageKey,
      places.map((place) => place.encode()).toList(growable: false),
    );
  }

  static NamedPlace? nearest(
    Iterable<NamedPlace> places,
    double latitude,
    double longitude,
  ) {
    const distance = Distance();
    NamedPlace? closest;
    var closestMeters = double.infinity;
    for (final place in places) {
      final meters = distance.as(
        LengthUnit.Meter,
        LatLng(latitude, longitude),
        LatLng(place.latitude, place.longitude),
      );
      if (meters <= place.radiusMeters && meters < closestMeters) {
        closest = place;
        closestMeters = meters;
      }
    }
    return closest;
  }
}
