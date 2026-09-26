import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/saved_place.dart';

class PlaceLabelsLayer {
  const PlaceLabelsLayer();

  List<Marker> build({
    required List<SavedPlace> places,
    required double zoom,
    required double latitude,
  }) {
    final candidates =
        places
            .map((place) => (place: place, point: _centroid(place.points)))
            .where((entry) => _visible(entry.place, zoom))
            .toList()
          ..sort((a, b) => _area(b.place).compareTo(_area(a.place)));
    final occupied = <LatLng>[];
    final minimumMeters =
        96 *
        156543.03392 *
        math.cos(latitude * math.pi / 180) /
        math.pow(2, zoom);
    final labels = <Marker>[];
    for (final candidate in candidates) {
      final collides = occupied.any(
        (point) =>
            const Distance().as(LengthUnit.Meter, point, candidate.point) <
            minimumMeters,
      );
      if (collides) continue;
      occupied.add(candidate.point);
      labels.add(
        Marker(
          point: candidate.point,
          width: 120,
          height: 32,
          alignment: Alignment.center,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Center(
                  child: Text(
                    candidate.place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return labels;
  }

  bool _visible(SavedPlace place, double zoom) {
    final diameter = place.circleRadiusMeters != null
        ? place.circleRadiusMeters! * 2
        : _area(place);
    final threshold = diameter >= 1000
        ? 8.0
        : diameter >= 300
        ? 10.0
        : 13.0;
    return zoom >= threshold;
  }

  double _area(SavedPlace place) {
    if (place.circleRadiusMeters case final radius?) {
      return radius * 2;
    }
    if (place.points.isEmpty) return 0;
    final latitudes = place.points.map((point) => point.latitude);
    final longitudes = place.points.map((point) => point.longitude);
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(latitudes.reduce(math.min), longitudes.reduce(math.min)),
      LatLng(latitudes.reduce(math.max), longitudes.reduce(math.max)),
    );
  }

  LatLng _centroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    return LatLng(
      points.map((point) => point.latitude).reduce((a, b) => a + b) /
          points.length,
      points.map((point) => point.longitude).reduce((a, b) => a + b) /
          points.length,
    );
  }
}
