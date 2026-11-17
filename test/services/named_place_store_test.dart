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

  group('named building margin', () {
    const building = NamedPlace(
      id: 'building',
      name: 'Building',
      latitude: 40.001,
      longitude: -73.9995,
      boundary: [
        LatLng(40, -74),
        LatLng(40, -73.999),
        LatLng(40.002, -73.999),
        LatLng(40.002, -74),
      ],
    );

    test('includes fixes within 20 meters of each edge', () {
      for (final point in const [
        LatLng(40.001, -74.0001),
        LatLng(40.001, -73.9989),
        LatLng(39.9999, -73.9995),
        LatLng(40.0021, -73.9995),
        LatLng(40.001, -74),
      ]) {
        expect(
          NamedPlaceStore.nearest([building], point.latitude, point.longitude),
          same(building),
        );
      }
      for (final point in const [
        LatLng(40.001, -74.0003),
        LatLng(40.001, -73.9987),
        LatLng(39.9998, -73.9995),
        LatLng(40.0022, -73.9995),
      ]) {
        expect(
          NamedPlaceStore.nearest([building], point.latitude, point.longitude),
          isNull,
        );
      }
    });

    test('measures corners by distance instead of expanding a bounding box', () {
      expect(
        NamedPlaceStore.nearest([building], 39.9999, -74.0001),
        same(building),
      );
      expect(
        NamedPlaceStore.nearest([building], 39.99985, -74.00015),
        isNull,
      );
    });

    test('overlapping margins choose the nearest edge in either list order', () {
      const neighbor = NamedPlace(
        id: 'neighbor',
        name: 'Neighbor',
        latitude: 40.001,
        longitude: -73.9986,
        boundary: [
          LatLng(40, -73.9987),
          LatLng(40, -73.9985),
          LatLng(40.002, -73.9985),
          LatLng(40.002, -73.9987),
        ],
      );
      for (final places in const [
        [building, neighbor],
        [neighbor, building],
      ]) {
        // The large building's edge is closer, despite its more distant center.
        expect(
          NamedPlaceStore.nearest(places, 40.001, -73.9989),
          same(building),
        );
        expect(
          NamedPlaceStore.nearest(places, 40.001, -73.9988),
          same(neighbor),
        );
        expect(
          NamedPlaceStore.nearest(places, 40.001, -73.99905),
          same(building),
        );
      }
    });

    test('longitude distances account for latitude', () {
      const polarBuilding = NamedPlace(
        id: 'polar',
        name: 'Polar building',
        latitude: 80.001,
        longitude: -73.9995,
        boundary: [
          LatLng(80, -74),
          LatLng(80, -73.999),
          LatLng(80.002, -73.999),
          LatLng(80.002, -74),
        ],
      );
      expect(
        NamedPlaceStore.nearest([polarBuilding], 80.001, -74.0008),
        same(polarBuilding),
      );
      expect(
        NamedPlaceStore.nearest([polarBuilding], 80.001, -74.0012),
        isNull,
      );
    });

    test('closed rings handle their repeated vertex', () {
      final closed = NamedPlace(
        id: building.id,
        name: building.name,
        latitude: building.latitude,
        longitude: building.longitude,
        boundary: [...building.boundary, building.boundary.first],
      );
      expect(
        NamedPlaceStore.nearest([closed], 40.001, -74.0001),
        same(closed),
      );
    });
  });
}
