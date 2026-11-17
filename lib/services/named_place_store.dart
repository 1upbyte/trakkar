import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/named_place.dart';

class NamedPlaceStore {
  NamedPlaceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'namedPlaces';
  static const _buildingBufferMeters = 20.0;
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
    var closestBoundaryMeters = double.infinity;
    var closestMeters = double.infinity;
    for (final place in places) {
      final meters = distance.as(
        LengthUnit.Meter,
        LatLng(latitude, longitude),
        LatLng(place.latitude, place.longitude),
      );
      final boundaryMeters = place.isPolygon
          ? polygonContains(place.boundary, latitude, longitude)
                ? 0.0
                : _distanceToBoundary(place.boundary, latitude, longitude)
          : math.max(0.0, meters - place.radiusMeters);
      final tolerance = place.isPolygon ? _buildingBufferMeters : 0.0;
      if (boundaryMeters > tolerance) continue;
      if (boundaryMeters < closestBoundaryMeters ||
          (boundaryMeters == closestBoundaryMeters && meters < closestMeters)) {
        closest = place;
        closestBoundaryMeters = boundaryMeters;
        closestMeters = meters;
      }
    }
    return closest;
  }

  /// Project nearby edges into meters around the fix, including the closing
  /// edge. Segment distance also gives corners a circular buffer.
  static double _distanceToBoundary(
    List<LatLng> boundary,
    double latitude,
    double longitude,
  ) {
    const metersPerDegree = 6371000 * math.pi / 180;
    final longitudeScale = metersPerDegree * math.cos(latitude * math.pi / 180);
    var closest = double.infinity;
    for (var i = 0; i < boundary.length; i++) {
      final start = boundary[i];
      final end = boundary[(i + 1) % boundary.length];
      final x = (start.longitude - longitude) * longitudeScale;
      final y = (start.latitude - latitude) * metersPerDegree;
      final dx = (end.longitude - start.longitude) * longitudeScale;
      final dy = (end.latitude - start.latitude) * metersPerDegree;
      final lengthSquared = dx * dx + dy * dy;
      final fraction = lengthSquared == 0
          ? 0.0
          : (-(x * dx + y * dy) / lengthSquared).clamp(0.0, 1.0);
      final nearestX = x + fraction * dx;
      final nearestY = y + fraction * dy;
      closest = math.min(
        closest,
        math.sqrt(nearestX * nearestX + nearestY * nearestY),
      );
    }
    return closest;
  }

  static bool polygonContains(
    List<LatLng> boundary,
    double latitude,
    double longitude,
  ) {
    var inside = false;
    for (
      var index = 0, previous = boundary.length - 1;
      index < boundary.length;
      previous = index++
    ) {
      final currentPoint = boundary[index];
      final previousPoint = boundary[previous];
      final crosses =
          (currentPoint.latitude > latitude) !=
              (previousPoint.latitude > latitude) &&
          longitude <
              (previousPoint.longitude - currentPoint.longitude) *
                      (latitude - currentPoint.latitude) /
                      (previousPoint.latitude - currentPoint.latitude) +
                  currentPoint.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }
}
