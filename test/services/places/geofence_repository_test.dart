import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/services/places/geofence_repository.dart';
import 'package:trakkar/services/traccar_data_repository.dart';

void main() {
  test('lists geofences with the authenticated server session', () async {
    final repository = TraccarDataRepository(
      managerUrl: 'https://tracker.example/root',
      sessionCookie: 'JSESSIONID=secret',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/root/api/geofences');
        expect(request.headers['cookie'], 'JSESSIONID=secret');
        return http.Response(
          jsonEncode([
            {'id': 7, 'name': 'Home', 'area': 'CIRCLE (35.7 -78.6, 100)'},
          ]),
          200,
        );
      }),
    );
    final geofences = TraccarGeofenceRepository(repository);
    expect((await geofences.list()).single.name, 'Home');
    await repository.close();
  });

  test(
    'creates trimmed names and deletes using authenticated requests',
    () async {
      final methods = <String>[];
      final repository = TraccarDataRepository(
        managerUrl: 'https://tracker.example',
        sessionCookie: 'JSESSIONID=secret',
        client: MockClient((request) async {
          methods.add(request.method);
          expect(request.headers['cookie'], 'JSESSIONID=secret');
          if (request.method == 'POST') {
            expect(request.url.path, '/api/geofences');
            expect(
              request.headers['content-type'],
              contains('application/json'),
            );
            expect(jsonDecode(request.body), {
              'name': 'Work',
              'area': 'POLYGON((0 0, 1 0, 0 1, 0 0))',
            });
            return http.Response('', 200);
          }
          expect(request.url.path, '/api/geofences/7');
          return http.Response('', 204);
        }),
      );
      final geofences = TraccarGeofenceRepository(repository);
      await geofences.create(
        name: '  Work  ',
        area: 'POLYGON((0 0, 1 0, 0 1, 0 0))',
      );
      await geofences.delete(7);
      expect(methods, ['POST', 'DELETE']);
      await repository.close();
    },
  );

  test('server failures surface only a generic geofence error', () async {
    final repository = TraccarDataRepository(
      managerUrl: 'https://tracker.example',
      sessionCookie: 'JSESSIONID=secret',
      client: MockClient((_) async => http.Response('private details', 503)),
    );
    await expectLater(
      TraccarGeofenceRepository(repository).delete(7),
      throwsA(isA<TraccarDataFailure>()),
    );
    await repository.close();
  });
}
