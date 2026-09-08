import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/building_lookup.dart';

/// Hit testing and highlights share the exact same footprint geometry.
class BuildingHighlights extends StatelessWidget {
  const BuildingHighlights({
    required this.buildings,
    required this.selectedIds,
    required this.hitNotifier,
    super.key,
  });

  final List<BuildingFootprint> buildings;
  final Set<String> selectedIds;
  final ValueNotifier<LayerHitResult<String>?> hitNotifier;

  @override
  Widget build(BuildContext context) {
    final ordered = [...buildings]
      ..sort(
        (a, b) => polygonArea(b.boundary).compareTo(polygonArea(a.boundary)),
      );
    return PolygonLayer<String>(
      hitNotifier: hitNotifier,
      polygons: [
        for (final building in ordered)
          Polygon<String>(
            points: building.boundary,
            holePointsList: building.holes,
            hitValue: building.id,
            color:
                (selectedIds.contains(building.id)
                        ? const Color(0xFF00A86B)
                        : const Color(0xFF268BFF))
                    .withValues(alpha: 0.28),
            borderColor: selectedIds.contains(building.id)
                ? const Color(0xFF00A86B)
                : const Color(0xFF268BFF),
            borderStrokeWidth: selectedIds.contains(building.id) ? 3 : 2,
          ),
      ],
    );
  }
}
