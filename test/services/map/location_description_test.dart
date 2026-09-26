import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/models/person.dart';
import 'package:trakkar/models/saved_place.dart';
import 'package:trakkar/services/map/location_description.dart';
import 'package:trakkar/services/traccar_data_repository.dart';

void main() {
  const person = PersonMapEntry(
    personId: '1',
    deviceId: 1,
    displayName: 'Morgan',
    imageRef: null,
    position: LatLng(35.7, -78.6),
    batteryLevel: null,
    fixTime: null,
  );

  test('containing saved place name takes priority over geocoding', () async {
    final repository = TraccarDataRepository(
      managerUrl: 'https://tracker.example',
      sessionCookie: 'session',
      client: MockClient((_) async => fail('Geocoder must not be called')),
    );
    const home = SavedPlace(
      id: 1,
      name: 'Home',
      points: [LatLng(35.7, -78.6)],
      circleRadiusMeters: 100,
    );
    expect(
      await LocationDescription(repository).describe(person, [home]),
      'Home',
    );
    await repository.close();
  });

  test('server reverse geocoder supplies readable location', () async {
    final repository = TraccarDataRepository(
      managerUrl: 'https://tracker.example',
      sessionCookie: 'session',
      client: MockClient((_) async => http.Response('Raleigh, NC', 200)),
    );
    expect(
      await LocationDescription(repository).describe(person, []),
      'Raleigh, NC',
    );
    await repository.close();
  });

  test(
    'geocoding failure reports connection failure and uses coordinates',
    () async {
      var failed = false;
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example',
        sessionCookie: 'session',
        client: MockClient((_) async => http.Response('offline details', 503)),
      );
      final result = await LocationDescription(repository)
          .describe(person, [], onServerFailure: () => failed = true);
      expect(result, '35.70000, -78.60000');
      expect(failed, isTrue);
      await repository.close();
    },
  );
}
