import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/services/settings/settings_repository.dart';

void main() {
  test('updates only the name while preserving server user fields', () async {
    final requests = <http.Request>[];
    final api = SettingsApiClient(
      managerUrl: 'https://manager.example/base',
      sessionCookie: 'token=secret',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 12,
              'name': 'Old name',
              'email': 'a@b.test',
              'attributes': {'role': 'admin'},
            }),
            200,
          );
        }
        return http.Response(jsonEncode(jsonDecode(request.body)), 200);
      }),
    );

    final profile = await TraccarProfileRepository(api)
        .updateDisplayName(' New name ');

    expect(profile.displayName, 'New name');
    final update = requests.last;
    expect(update.url.path, '/base/api/users/12');
    expect(update.headers['cookie'], 'token=secret');
    expect(jsonDecode(update.body), {
      'id': 12,
      'name': 'New name',
      'email': 'a@b.test',
      'attributes': {'role': 'admin'},
    });
    api.close();
  });

  test(
    'does not return a profile when the server rejects the update',
    () async {
      var calls = 0;
      final api = SettingsApiClient(
        managerUrl: 'https://manager.example',
        sessionCookie: 'token=secret',
        client: MockClient((request) async {
          calls++;
          if (request.method == 'GET') {
            return http.Response('{"id":1,"name":"Old"}', 200);
          }
          return http.Response('', 500);
        }),
      );
      await expectLater(
        TraccarProfileRepository(api).updateDisplayName('New'),
        throwsA(isA<SettingsRepositoryFailure>()),
      );
      expect(calls, 2);
      api.close();
    },
  );
}
