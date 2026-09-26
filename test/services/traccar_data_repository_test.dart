import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/models/person.dart';
import 'package:trakkar/services/traccar_data_repository.dart';

void main() {
  test(
    'loads authorized devices, latest positions, saved places and key',
    () async {
      final paths = <String>[];
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example/prefix/',
        sessionCookie: 'JSESSIONID=secret',
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['cookie'], 'JSESSIONID=secret');
          switch (request.url.path) {
            case '/prefix/api/devices':
              return http.Response(
                jsonEncode([
                  {
                    'id': 7,
                    'name': 'Jordan Doe',
                    'attributes': {'batteryLevel': 72},
                  },
                  {'id': 8, 'name': 'No location'},
                ]),
                200,
              );
            case '/prefix/api/positions':
              return http.Response(
                jsonEncode([
                  {
                    'deviceId': 7,
                    'latitude': 35.7,
                    'longitude': -78.6,
                    'address': 'Raleigh, NC',
                    'fixTime': '2026-09-26T12:00:00Z',
                  },
                  {'deviceId': 999, 'latitude': 1, 'longitude': 1},
                ]),
                200,
              );
            case '/prefix/api/geofences':
              return http.Response(
                jsonEncode([
                  {'id': 3, 'name': 'Home', 'area': 'CIRCLE (35.7 -78.6, 100)'},
                ]),
                200,
              );
            case '/prefix/api/server':
              return http.Response(
                jsonEncode({
                  'attributes': {'trakkarMapTilerKey': 'key-kept-in-memory'},
                }),
                200,
              );
            default:
              return http.Response('', 404);
          }
        }),
      );

      final snapshot = await repository.loadMap();
      expect(
        paths,
        containsAll([
          '/prefix/api/devices',
          '/prefix/api/positions',
          '/prefix/api/geofences',
          '/prefix/api/server',
        ]),
      );
      expect(snapshot.people, hasLength(2));
      expect(snapshot.people.first.position, const LatLng(35.7, -78.6));
      expect(snapshot.people.first.address, 'Raleigh, NC');
      expect(snapshot.people.first.batteryLevel, 72);
      expect(snapshot.people.last.position, isNull);
      expect(snapshot.places.single.name, 'Home');
      expect(snapshot.mapTilerKey, 'key-kept-in-memory');
      await repository.close();
    },
  );

  test(
    'server errors become generic failures without response details',
    () async {
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example',
        sessionCookie: 'JSESSIONID=secret',
        client: MockClient((_) async => http.Response('password secret', 503)),
      );
      await expectLater(
        repository.loadMap(),
        throwsA(
          isA<TraccarDataFailure>().having(
            (failure) => failure.toString(),
            'safe message',
            isNot(contains('password secret')),
          ),
        ),
      );
      await repository.close();
    },
  );

  test(
    'reverse geocoding uses authenticated server endpoint and coordinates',
    () async {
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example',
        sessionCookie: 'JSESSIONID=secret',
        client: MockClient((request) async {
          expect(request.url.path, '/api/server/geocode');
          expect(request.url.queryParameters['latitude'], '35.5');
          expect(request.url.queryParameters['longitude'], '-78.5');
          expect(request.headers['cookie'], 'JSESSIONID=secret');
          return http.Response('Server address', 200);
        }),
      );
      expect(
        await repository.reverseGeocode(const LatLng(35.5, -78.5)),
        'Server address',
      );
      await repository.close();
    },
  );

  test(
    'uploaded Traccar device image is fetched from server with session cookie',
    () async {
      final person = PersonMapEntry.fromTraccar(
        device: {
          'id': 4,
          'name': 'Jordan Doe',
          'uniqueId': 'device-serial',
          'attributes': {'deviceImage': 'portrait.png'},
        },
      );
      expect(person.imageRef, 'traccar-media:device-serial/portrait.png');
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example/prefix',
        sessionCookie: 'JSESSIONID=secret',
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/prefix/api/media/device-serial/portrait.png',
          );
          expect(request.headers['cookie'], 'JSESSIONID=secret');
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      expect(await repository.loadProfileImage(person.imageRef!), [1, 2, 3]);
      await repository.close();
    },
  );

  test(
    'external image requests do not receive the Traccar session cookie',
    () async {
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example',
        sessionCookie: 'JSESSIONID=secret',
        client: MockClient((request) async {
          expect(request.url.host, 'images.example');
          expect(request.headers.containsKey('cookie'), isFalse);
          return http.Response.bytes([1], 200);
        }),
      );
      await repository.loadProfileImage('https://images.example/avatar.png');
      await repository.close();
    },
  );
}
