import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/services/places/place_geometry.dart';

void main() {
  test('rejects fewer than three distinct vertices and repeated vertices', () {
    expect(
      PlaceGeometry.validationError(const [LatLng(0, 0), LatLng(1, 1)]),
      isNotNull,
    );
    expect(
      PlaceGeometry.validationError(const [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 0),
        LatLng(0, 1),
      ]),
      isNotNull,
    );
  });

  test('rejects collinear, non-finite and out-of-range coordinates', () {
    expect(
      PlaceGeometry.validationError(const [
        LatLng(0, 0),
        LatLng(1, 1),
        LatLng(2, 2),
      ]),
      isNotNull,
    );
    expect(
      PlaceGeometry.validationError([
        const LatLng(0, 0),
        const LatLng(0, 1),
        LatLng(double.nan, 0),
      ]),
      isNotNull,
    );
    expect(
      PlaceGeometry.validationError(const [
        LatLng(0, 0),
        LatLng(0, 181),
        LatLng(1, 0),
      ]),
      isNotNull,
    );
  });

  test('normalizes a closed ring and serializes longitude latitude WKT', () {
    const points = [
      LatLng(35, -79),
      LatLng(35, -78),
      LatLng(36, -78),
      LatLng(35, -79),
    ];
    expect(PlaceGeometry.validationError(points), isNull);
    expect(
      PlaceGeometry.toWktPolygon(points),
      'POLYGON((-79 35, -78 35, -78 36, -79 35))',
    );
  });

  test('accepts a valid polygon and rejects self-intersection', () {
    expect(
      PlaceGeometry.validationError(const [
        LatLng(0, 0),
        LatLng(0, 2),
        LatLng(2, 2),
        LatLng(2, 0),
      ]),
      isNull,
    );
    expect(
      PlaceGeometry.validationError(const [
        LatLng(0, 0),
        LatLng(2, 2),
        LatLng(0, 2),
        LatLng(2, 0),
      ]),
      isNotNull,
    );
  });
}
