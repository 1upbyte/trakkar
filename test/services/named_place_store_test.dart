import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/named_place.dart';
import 'package:trakkar/services/named_place_store.dart';

void main() {
  test('nearest returns a named place only inside its radius', () {
    const home = NamedPlace(
      id: 'home',
      name: 'Home',
      latitude: 40.7128,
      longitude: -74.006,
      radiusMeters: 200,
    );

    expect(NamedPlaceStore.nearest(const [home], 40.713, -74.006), same(home));
    expect(NamedPlaceStore.nearest(const [home], 40.72, -74.006), isNull);
  });

  test('parses Traccar circle latitude, longitude, and radius', () {
    final place = NamedPlace.fromGeofence({
      'id': 42,
      'name': 'Work',
      'area': 'CIRCLE (40.7128 -74.006, 125.5)',
    });

    expect(place.id, '42');
    expect(place.latitude, 40.7128);
    expect(place.longitude, -74.006);
    expect(place.radiusMeters, 125.5);
    expect(place.serverBacked, isTrue);
  });
}
