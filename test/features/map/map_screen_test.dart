import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/features/map/map_screen.dart';
import 'package:trakkar/services/traccar_data_repository.dart';

Future<MapStyleSet> emptyStyles(String? _) async => MapStyleSet(
  standard: vt.Style(
    theme: const vt.Theme(id: 'test', layers: []),
    providers: const vt.TileProviders({}),
  ),
);

void main() {
  testWidgets(
    'map server failure shows shared Retry and retry repeats requests',
    (tester) async {
      var requests = 0;
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example',
        sessionCookie: 'session',
        client: MockClient((_) async {
          requests++;
          return http.Response('private server error', 503);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapScreen(
              repository: repository,
              satelliteThresholdZoom: 19,
              onSatelliteUnavailable: (_) {},
              styleLoader: emptyStyles,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connection to server failed'), findsOneWidget);
      expect(find.text('private server error'), findsNothing);
      final beforeRetry = requests;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(requests, greaterThan(beforeRetry));
      expect(find.text('Connection to server failed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );
}
