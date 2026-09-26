import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/map/map_camera_policy.dart';

void main() {
  const policy = MapCameraPolicy();

  test('empty positions use a stable world view', () {
    final camera = policy.initialCamera(const []);
    expect(camera.center, const LatLng(20, 0));
    expect(camera.zoom, 2);
  });

  test('single position is centered at a useful close zoom', () {
    final camera = policy.initialCamera([const LatLng(35, -78)]);
    expect(camera.center, const LatLng(35, -78));
    expect(camera.zoom, 15);
  });

  test('multiple positions fit while their span stays within two miles', () {
    final camera = policy.initialCamera([
      const LatLng(35, -78),
      const LatLng(35.005, -78.005),
    ]);
    expect(camera.center.latitude, closeTo(35.0025, 0.0001));
    expect(camera.center.longitude, closeTo(-78.0025, 0.0001));
    expect(camera.zoom, greaterThan(12));
  });

  test('widely spread positions use the outward framing cap', () {
    final withinCap = policy.initialCamera([
      const LatLng(35, -78),
      const LatLng(35.005, -78.005),
    ]);
    final outsideCap = policy.initialCamera([
      const LatLng(35, -78),
      const LatLng(36, -79),
    ]);
    expect(outsideCap.zoom, lessThan(withinCap.zoom));
    expect(outsideCap.zoom, inInclusiveRange(12, 15));
  });
}
