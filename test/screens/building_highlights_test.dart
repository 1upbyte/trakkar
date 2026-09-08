import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/services/building_lookup.dart';
import 'package:trakkar/widgets/building_highlights.dart';

void main() {
  testWidgets('highlighted footprint is tappable and courtyard is not', (
    tester,
  ) async {
    final hits = ValueNotifier<LayerHitResult<String>?>(null);
    final controller = MapController();
    String? selected;
    const building = BuildingFootprint(
      id: 'building',
      boundary: [
        LatLng(-0.001, -0.001),
        LatLng(-0.001, 0.001),
        LatLng(0.001, 0.001),
        LatLng(0.001, -0.001),
      ],
      holes: [
        [
          LatLng(-0.0002, -0.0002),
          LatLng(-0.0002, 0.0002),
          LatLng(0.0002, 0.0002),
          LatLng(0.0002, -0.0002),
        ],
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 18,
              onTap: (_, _) => selected = hits.value?.hitValues.firstOrNull,
            ),
            children: [
              BuildingHighlights(
                buildings: const [building],
                selectedIds: const {},
                hitNotifier: hits,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      controller.camera.latLngToScreenOffset(const LatLng(0.0007, 0)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(selected, 'building');
    await tester.tapAt(
      controller.camera.latLngToScreenOffset(const LatLng(0, 0)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(selected, isNull);
    final polygon = tester
        .widget<PolygonLayer<String>>(find.byType(PolygonLayer<String>))
        .polygons
        .single;
    expect(polygon.hitValue, building.id);
    expect(polygon.holePointsList, building.holes);
    await tester.pumpWidget(const SizedBox());
    hits.dispose();
    controller.dispose();
  });
}
