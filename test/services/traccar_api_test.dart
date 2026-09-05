import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/models/named_place.dart';
import 'package:trakkar/models/provisioning_config.dart';
import 'package:trakkar/models/traccar_device.dart';
import 'package:trakkar/services/traccar_api.dart';

void main() {
  final config = ProvisioningConfig(
    clientUrl: Uri(scheme: 'https', host: 'client.test'),
    managerUrl: Uri(scheme: 'https', host: 'manager.test', path: '/api'),
    managerUsername: 'manager',
    managerPassword: 'password',
  );

  test(
    'uses a Traccar session cookie for device and position requests',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/session') {
          return http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'JSESSIONID=session-123; Path=/; HttpOnly'},
          );
        }
        if (request.url.path == '/api/devices') {
          return http.Response(
            '[{"id":1,"name":"Pablo","uniqueId":"pablo",'
            '"status":"online","attributes":{}}]',
            200,
          );
        }
        if (request.url.path == '/api/positions') {
          return http.Response(
            '[{"id":9,"deviceId":1,"latitude":40.7,"longitude":-74.0,'
            '"valid":true}]',
            200,
          );
        }
        return http.Response('', 404);
      });
      final api = TraccarApi(config: config, client: client);

      await api.login();
      final devices = await api.devices();
      final positions = await api.positions();

      expect(devices.single.uniqueId, 'pablo');
      expect(positions.single.deviceId, 1);
      expect(requests[1].headers['Cookie'], 'JSESSIONID=session-123');
      expect(requests[2].headers['Cookie'], 'JSESSIONID=session-123');
    },
  );

  test('loads the MapTiler key from server attributes', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/session') {
        return http.Response(
          '{}',
          200,
          headers: {'set-cookie': 'JSESSIONID=config'},
        );
      }
      expect(request.url.path, '/api/server');
      expect(request.headers['Cookie'], 'JSESSIONID=config');
      return http.Response(
        jsonEncode({
          'id': 1,
          'attributes': {'trakkarMapTilerKey': ' server-key '},
        }),
        200,
      );
    });
    final api = TraccarApi(config: config, client: client);

    await api.login();

    expect(await api.mapTilerApiKey(), 'server-key');
  });

  test('findDevice falls back when all=true is not permitted', () async {
    var deviceRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/session') {
        return http.Response(
          '{}',
          200,
          headers: {'set-cookie': 'JSESSIONID=x'},
        );
      }
      deviceRequests += 1;
      expect(request.url.queryParameters['uniqueId'], 'alice');
      if (request.url.queryParameters['all'] == 'true') {
        return http.Response('No permission', 400);
      }
      return http.Response(
        jsonEncode([
          {
            'id': 2,
            'name': 'Alice',
            'uniqueId': 'alice',
            'status': 'offline',
            'attributes': <String, dynamic>{},
          },
        ]),
        200,
      );
    });
    final api = TraccarApi(config: config, client: client);

    await api.login();
    final device = await api.findDevice('alice');

    expect(device?.name, 'Alice');
    expect(deviceRequests, 2);
  });

  test('wrong-password errors never expose the server response body', () async {
    final client = MockClient(
      (_) async => http.Response(
        'java.lang.SecurityException: internal server detail',
        401,
      ),
    );
    final api = TraccarApi(config: config, client: client);

    await expectLater(
      api.login(),
      throwsA(
        isA<TraccarApiException>()
            .having(
              (error) => error.message,
              'message',
              'The manager username or password is incorrect.',
            )
            .having(
              (error) => error.message,
              'safe message',
              isNot(contains('SecurityException')),
            ),
      ),
    );
  });

  test(
    'stores and reads friendly places as tagged circular geofences',
    () async {
      final methods = <String>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/session') {
          return http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'JSESSIONID=places'},
          );
        }
        methods.add(request.method);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 7,
                'name': 'Home',
                'area': 'CIRCLE (40.7 -74.0, 150)',
                'attributes': {'trakkarNamedPlace': true},
              },
              {
                'id': 8,
                'name': 'Normal Traccar geofence',
                'area': 'CIRCLE (1 2, 25)',
                'attributes': <String, dynamic>{},
              },
            ]),
            200,
          );
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map;
          expect(body['area'], 'CIRCLE (40.7 -74.0, 200.0)');
          expect((body['attributes'] as Map)['trakkarNamedPlace'], isTrue);
          return http.Response(
            jsonEncode({...Map<String, dynamic>.from(body), 'id': 9}),
            200,
          );
        }
        expect(request.url.path, '/api/geofences/9');
        return http.Response('', 204);
      });
      final api = TraccarApi(config: config, client: client);

      await api.login();
      final existing = await api.namedPlaces();
      final created = await api.createNamedPlace(
        name: 'Work',
        latitude: 40.7,
        longitude: -74,
        radiusMeters: 200,
      );
      await api.deleteNamedPlace(created.serverId!);

      expect(existing.single.name, 'Home');
      expect(existing.single.serverBacked, isTrue);
      expect(created.id, '9');
      expect(methods, ['GET', 'POST', 'DELETE']);
    },
  );

  test('stores a drawn place as a tagged polygon geofence', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      if (request.url.path == '/api/session') {
        return http.Response(
          '{}',
          200,
          headers: {'set-cookie': 'JSESSIONID=polygon'},
        );
      }
      requestBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      return http.Response(jsonEncode({...requestBody, 'id': 10}), 200);
    });
    final api = TraccarApi(config: config, client: client);

    await api.login();
    final created = await api.createNamedPlace(
      name: 'Park',
      latitude: 40.05,
      longitude: -73.95,
      radiusMeters: 150,
      boundary: const [LatLng(40, -74), LatLng(40, -73.9), LatLng(40.1, -73.9)],
    );

    expect(
      requestBody['area'],
      'POLYGON ((40.0 -74.0, 40.0 -73.9, 40.1 -73.9, 40.0 -74.0))',
    );
    expect(created.isPolygon, isTrue);
  });

  test(
    'idempotently links named places and one exit notification to devices',
    () async {
      final linkedGeofences = <int>{};
      final linkedNotifications = <int>{};
      Map<String, dynamic>? createdNotification;
      var notificationCreates = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/session') {
          return http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'JSESSIONID=monitoring'},
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/geofences') {
          expect(request.url.queryParameters['deviceId'], '1');
          return http.Response(
            jsonEncode(linkedGeofences.map((id) => {'id': id}).toList()),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/notifications' &&
            request.url.queryParameters.containsKey('deviceId')) {
          expect(request.url.queryParameters['deviceId'], '1');
          return http.Response(
            jsonEncode(linkedNotifications.map((id) => {'id': id}).toList()),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/notifications') {
          return http.Response(
            jsonEncode(
              createdNotification == null ? [] : [createdNotification],
            ),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/notifications') {
          notificationCreates += 1;
          final body = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          expect(body['type'], 'geofenceExit');
          expect(body['notificators'], 'web');
          expect(
            (body['attributes'] as Map)['trakkarNamedPlaceExitNotification'],
            isTrue,
          );
          createdNotification = <String, dynamic>{...body, 'id': 20};
          return http.Response(jsonEncode(createdNotification), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/permissions') {
          final body = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          expect(body['deviceId'], 1);
          if (body['geofenceId'] case final int geofenceId) {
            linkedGeofences.add(geofenceId);
          }
          if (body['notificationId'] case final int notificationId) {
            linkedNotifications.add(notificationId);
          }
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });
      final api = TraccarApi(config: config, client: client);
      final device = TraccarDevice.fromJson({
        'id': 1,
        'name': 'Pablo',
        'uniqueId': 'pablo',
        'attributes': <String, dynamic>{},
      });
      const place = NamedPlace(
        id: '7',
        name: 'Home',
        latitude: 40.7,
        longitude: -74,
        serverBacked: true,
      );

      await api.login();
      await api.ensureNamedPlaceExitMonitoring(
        places: const [place],
        devices: [device],
      );
      await api.ensureNamedPlaceExitMonitoring(
        places: const [place],
        devices: [device],
      );

      expect(linkedGeofences, {7});
      expect(linkedNotifications, {20});
      expect(notificationCreates, 1);
    },
  );

  test(
    'uploads an avatar and saves the returned deviceImage attribute',
    () async {
      final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
      late Map<String, dynamic> updateBody;
      final client = MockClient((request) async {
        if (request.url.path == '/api/session') {
          return http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'JSESSIONID=image'},
          );
        }
        if (request.url.path == '/api/devices/1/image') {
          expect(request.headers['content-type'], startsWith('image/jpeg'));
          expect(request.bodyBytes, imageBytes);
          return http.Response('device.jpg', 200);
        }
        updateBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return http.Response(jsonEncode(updateBody), 200);
      });
      final api = TraccarApi(config: config, client: client);
      final device = TraccarDevice.fromJson({
        'id': 1,
        'name': 'Pablo',
        'uniqueId': 'pablo',
        'attributes': {'existing': true},
      });

      await api.login();
      final updated = await api.uploadDeviceImage(
        device,
        imageBytes,
        'image/jpeg',
      );

      expect(updated.imageName, 'device.jpg');
      expect(updateBody['attributes'], {
        'existing': true,
        'deviceImage': 'device.jpg',
      });
    },
  );
}
