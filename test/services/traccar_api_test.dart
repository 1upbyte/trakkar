import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/models/provisioning_config.dart';
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
}
