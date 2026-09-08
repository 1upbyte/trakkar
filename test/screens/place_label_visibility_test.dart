import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/models/named_place.dart';
import 'package:trakkar/screens/map_screen.dart';

void main() {
  test('small places disappear before large places as the map zooms out', () {
    const small = NamedPlace(
      id: '1',
      name: 'Home',
      latitude: 0,
      longitude: 0,
      radiusMeters: 20,
    );
    const large = NamedPlace(
      id: '2',
      name: 'Park',
      latitude: 0,
      longitude: 0,
      radiusMeters: 500,
    );
    expect(placeLabelVisible(small, 19), isTrue);
    expect(placeLabelVisible(small, 15), isFalse);
    expect(placeLabelVisible(large, 15), isTrue);
    expect(placeLabelVisible(large, 10), isFalse);
  });

  test(
    'polygon labels use the boundary size instead of the default radius',
    () {
      const place = NamedPlace(
        id: '1',
        name: 'Building',
        latitude: 0,
        longitude: 0,
        boundary: [
          LatLng(0, 0),
          LatLng(0, 0.0002),
          LatLng(0.0002, 0.0002),
          LatLng(0.0002, 0),
        ],
      );
      expect(placeLabelVisible(place, 15), isFalse);
      expect(placeLabelVisible(place, 20), isTrue);
    },
  );
}
