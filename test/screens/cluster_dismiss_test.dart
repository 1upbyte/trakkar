import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
    'outside tap keeps the group expanded; tapping the group collapses it',
    (tester) async {
      var collapsed = 0;
      var personTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 12,
              ),
              children: [
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxZoom: 21,
                    disableClusteringAtZoom: 22,
                    zoomToBoundsOnClick: false,
                    showPolygon: false,
                    markerChildBehavior: true,
                    onMarkersClustered: (_) => collapsed++,
                    markers: [
                      for (var i = 0; i < 2; i++)
                        Marker(
                          point: const LatLng(0, 0),
                          width: 30,
                          height: 30,
                          child: GestureDetector(
                            onTap: () => personTaps++,
                            child: ColoredBox(
                              key: ValueKey('person$i'),
                              color: Colors.blue,
                              child: Text('$i'),
                            ),
                          ),
                        ),
                    ],
                    builder: (_, _) => const ColoredBox(
                      key: ValueKey('cluster'),
                      color: Colors.red,
                      child: Text('Group'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cluster')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('person0')).last);
      await tester.pumpAndSettle();
      expect(personTaps, 1);
      expect(collapsed, 0);
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(collapsed, 0);
      await tester.tap(find.byKey(const ValueKey('cluster')).first);
      await tester.pumpAndSettle();
      expect(collapsed, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
