import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  for (final duringExpansion in [true, false]) {
    for (final moves in [false, true]) {
      testWidgets(
        '${moves ? 'location update' : 'rebuild'} '
        '${duringExpansion ? 'during' : 'after'} expansion keeps the group open',
        (tester) async {
          var personTaps = 0;
          var collapsed = 0;
          final controller = MapController();
          final markers = ValueNotifier(
            _markers(0, 'initial', () => personTaps++),
          );
          addTearDown(controller.dispose);
          addTearDown(markers.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FlutterMap(
                  mapController: controller,
                  options: const MapOptions(
                    initialCenter: LatLng(0, 0),
                    initialZoom: 12,
                  ),
                  children: [
                    ValueListenableBuilder<List<Marker>>(
                      valueListenable: markers,
                      builder: (_, latest, _) => MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxZoom: 21,
                          disableClusteringAtZoom: 22,
                          zoomToBoundsOnClick: false,
                          spiderfyCircleRadius: 72,
                          showPolygon: false,
                          markerChildBehavior: true,
                          onMarkersClustered: (_) => collapsed++,
                          markers: latest,
                          builder: (_, _) => const ColoredBox(
                            key: ValueKey('cluster'),
                            color: Colors.red,
                            child: Text('Group'),
                          ),
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
          await tester.pump();
          if (duringExpansion) {
            await tester.pump(const Duration(milliseconds: 100));
          } else {
            await tester.pumpAndSettle();
          }

          // Recreate keyed markers just as MapScreen does on an AppState update.
          // GPS jitter changes the group's center without changing its members.
          markers.value = _markers(
            moves ? 0.0001 : 0,
            'updated',
            () => personTaps++,
          );
          await tester.pumpAndSettle();
          expect(find.text('updated0'), findsOneWidget);
          expect(find.text('updated1'), findsOneWidget);
          expect(collapsed, 0);
          await tester.tap(find.text('updated0'));
          expect(personTaps, 1);

          // The rebuilt group must still collapse on the very next tap.
          await tester.tap(find.byKey(const ValueKey('cluster')).first);
          await tester.pumpAndSettle();
          expect(collapsed, 1);
          expect(find.text('updated0'), findsNothing);
          await tester.tap(find.byKey(const ValueKey('cluster')).first);
          await tester.pumpAndSettle();
          expect(find.text('updated0'), findsOneWidget);

          // Deliberately zooming still closes the expanded group.
          controller.move(const LatLng(0, 0), 13);
          await tester.pumpAndSettle();
          expect(collapsed, 2);
          expect(find.text('updated0'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }
}

List<Marker> _markers(double latitude, String label, VoidCallback onTap) => [
  for (var i = 0; i < 2; i++)
    Marker(
      key: ValueKey(i),
      point: LatLng(latitude, 0),
      width: 50,
      height: 30,
      child: GestureDetector(
        onTap: onTap,
        child: ColoredBox(color: Colors.blue, child: Text('$label$i')),
      ),
    ),
];
