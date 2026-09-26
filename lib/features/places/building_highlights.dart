import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'building_lookup.dart';

class BuildingHighlights {
  const BuildingHighlights._();

  static List<Polygon> build({
    required Iterable<BuildingCandidate> candidates,
    required String? selectedId,
  }) => [
    for (final candidate in candidates)
      Polygon(
        points: candidate.points,
        color: candidate.id == selectedId
            ? Colors.amber.withValues(alpha: 0.35)
            : Colors.lightBlue.withValues(alpha: 0.12),
        borderColor: candidate.id == selectedId
            ? Colors.amber.shade800
            : Colors.lightBlue.shade700,
        borderStrokeWidth: candidate.id == selectedId ? 4 : 2,
      ),
  ];

  static Polygon draft(List<LatLng> points) => Polygon(
    points: points,
    color: Colors.amber.withValues(alpha: 0.3),
    borderColor: Colors.amber.shade900,
    borderStrokeWidth: 4,
  );
}
