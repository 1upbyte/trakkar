import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
