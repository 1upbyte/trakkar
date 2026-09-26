import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/map/map_camera_policy.dart';
import 'package:trakkar/models/map_view_state.dart';

void main() {
  test('selection captures and restores the exact prior map camera once', () {
    final selection = MapSelectionState();
    const snapshot = MapViewSnapshot(
      center: LatLng(35.7, -78.6),
      zoom: 11.25,
      rotation: 18,
    );
    expect(selection.select('device-1', snapshot), isTrue);
    expect(selection.value.selectedPersonId, 'device-1');
    expect(selection.select('device-2', snapshot), isFalse);
    expect(selection.restore(), snapshot);
    expect(selection.value.selectedPersonId, isNull);
    expect(selection.restore(), isNull);
  });

  test(
    'camera policy snapshots center, zoom and rotation without rounding',
    () {
      final camera = MapCameraPolicy();
      final view = MapViewSnapshot(
        center: const LatLng(40.1, -74.3),
        zoom: 12.375,
        rotation: 27.5,
      );
      expect(view.center, const LatLng(40.1, -74.3));
      expect(view.zoom, 12.375);
      expect(view.rotation, 27.5);
      expect(
        camera.initialCamera([const LatLng(40.1, -74.3)]).center,
        view.center,
      );
    },
  );
}
