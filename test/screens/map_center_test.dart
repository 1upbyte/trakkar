import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/models/traccar_position.dart';
import 'package:trakkar/screens/map_screen.dart';

Future<MapController> _showMap(WidgetTester tester, List<LatLng> points) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final state = AppState()
    ..positions = {
      for (final (index, point) in points.indexed)
        index: TraccarPosition(
          id: index,
          deviceId: index,
          latitude: point.latitude,
          longitude: point.longitude,
          valid: true,
        ),
    };
  addTearDown(state.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: MapScreen(visible: true)),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
}

Future<void> _centerMap(WidgetTester tester) async {
  final button = defaultTargetPlatform == TargetPlatform.iOS
      ? find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right)
      : find.byTooltip('Center on group');
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  const home = LatLng(40.7, -74);
  const nearby = LatLng(40.73, -73.99);
  const fartherAway = LatLng(34.05, -118.25);

  testWidgets('centering keeps the local group and skips a distant person', (
    tester,
  ) async {
    final controller = await _showMap(tester, [
      fartherAway,
      home,
      home,
      home,
      nearby,
    ]);
    expect(controller.camera.visibleBounds.contains(fartherAway), isTrue);
    final initialZoom = controller.camera.zoom;

    await _centerMap(tester);

    final camera = controller.camera;
    expect(camera.zoom, greaterThan(initialZoom));
    expect(camera.visibleBounds.contains(home), isTrue);
    expect(camera.visibleBounds.contains(nearby), isTrue);
    expect(camera.visibleBounds.contains(fartherAway), isFalse);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('centering keeps both people when there is no majority group', (
    tester,
  ) async {
    final controller = await _showMap(tester, [home, fartherAway]);

    await _centerMap(tester);

    expect(controller.camera.visibleBounds.contains(home), isTrue);
    expect(controller.camera.visibleBounds.contains(fartherAway), isTrue);
  }, variant: TargetPlatformVariant.mobile());
}
