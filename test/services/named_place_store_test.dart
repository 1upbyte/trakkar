import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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
    expect(place.notifyOnExit, isTrue);
  });

  test('preserves an explicit named-place exit alert opt-out', () {
    final place = NamedPlace.fromGeofence({
      'id': 44,
      'name': 'Quiet place',
      'area': 'CIRCLE (40.7128 -74.006, 150)',
      'attributes': {'trakkarNamedPlace': true, 'trakkarNotifyOnExit': false},
    });

    expect(place.notifyOnExit, isFalse);
    expect(
      (place.toGeofencePayload()['attributes'] as Map)['trakkarNotifyOnExit'],
      isFalse,
    );
  });

  test('parses and writes a drawn Traccar polygon', () {
    final place = NamedPlace.fromGeofence({
      'id': 43,
      'name': 'School',
      'area': 'POLYGON ((40.0 -74.0, 40.0 -73.9, 40.1 -73.9, 40.0 -74.0))',
    });

    expect(place.isPolygon, isTrue);
    expect(place.boundary, const [
      LatLng(40, -74),
      LatLng(40, -73.9),
      LatLng(40.1, -73.9),
    ]);
    expect(
      place.toGeofencePayload()['area'],
      'POLYGON ((40.0 -74.0, 40.0 -73.9, 40.1 -73.9, 40.0 -74.0))',
    );
  });

  test('nearest uses a drawn boundary instead of its radius', () {
    const yard = NamedPlace(
      id: 'yard',
      name: 'Yard',
      latitude: 40.05,
      longitude: -73.95,
      radiusMeters: 10,
      boundary: [
        LatLng(40, -74),
        LatLng(40, -73.9),
        LatLng(40.1, -73.9),
        LatLng(40.1, -74),
      ],
    );

    expect(NamedPlaceStore.nearest(const [yard], 40.05, -73.95), same(yard));
    expect(NamedPlaceStore.nearest(const [yard], 40.2, -73.95), isNull);
  });

  test('local JSON retains a drawn boundary', () {
    const original = NamedPlace(
      id: 'yard',
      name: 'Yard',
      latitude: 40,
      longitude: -74,
      boundary: [LatLng(40, -74), LatLng(40, -73), LatLng(41, -73)],
    );

    final restored = NamedPlace.fromJson(original.toJson());

    expect(restored.boundary, original.boundary);
    expect(restored.isPolygon, isTrue);
  });
}
