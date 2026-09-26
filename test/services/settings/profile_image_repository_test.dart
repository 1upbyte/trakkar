import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/models/user_profile.dart';
import 'package:trakkar/services/settings/profile_image_repository.dart';
import 'package:trakkar/services/settings/settings_repository.dart';

void main() {
  test('loads image from the server device image attribute', () async {
    final api = SettingsApiClient(
      managerUrl: 'https://manager.example',
      sessionCookie: 'session=secret',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'id': 8,
              'uniqueId': 'device-1',
              'attributes': {'deviceImage': 'portrait.jpg'},
            },
          ]),
          200,
        ),
      ),
    );
    final repository = TraccarProfileImageRepository(api);
    expect(
      await repository.loadImageRef('device-1'),
      'traccar-media:device-1/portrait.jpg',
    );
    api.close();
  });

  test(
    'uploads bytes and saves returned filename without dropping attributes',
    () async {
      final requests = <http.Request>[];
      final api = SettingsApiClient(
        managerUrl: 'https://manager.example',
        sessionCookie: 'session=secret',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'id': 8,
                  'uniqueId': 'device-1',
                  'name': 'Phone',
                  'attributes': {'color': 'blue'},
                },
              ]),
              200,
            );
          }
          if (request.method == 'POST') {
            return http.Response('uploaded.jpg', 200);
          }
          return http.Response(jsonEncode(jsonDecode(request.body)), 200);
        }),
      );
      final profile = const UserProfile(userId: 5, displayName: 'Alex');
      final updated = await TraccarProfileImageRepository(api).upload(
        profile: profile,
        deviceUniqueId: 'device-1',
        bytes: [1, 2, 3],
        contentType: 'image/jpeg',
      );
      expect(updated.profileImageRef, 'traccar-media:device-1/uploaded.jpg');
      expect(requests[1].url.path, '/api/devices/8/image');
      expect(requests[1].bodyBytes, [1, 2, 3]);
      final saved = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(saved['attributes'], {
        'color': 'blue',
        'deviceImage': 'uploaded.jpg',
      });
      api.close();
    },
  );

  test('keeps the previously committed profile when upload fails', () async {
    final api = SettingsApiClient(
      managerUrl: 'https://manager.example',
      sessionCookie: 'session=secret',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {'id': 8, 'uniqueId': 'device-1'},
            ]),
            200,
          );
        }
        return http.Response('', 500);
      }),
    );
    final previous = const UserProfile(
      userId: 5,
      displayName: 'Alex',
      profileImageRef: 'old.jpg',
    );
    await expectLater(
      TraccarProfileImageRepository(api).upload(
        profile: previous,
        deviceUniqueId: 'device-1',
        bytes: [1],
        contentType: 'image/jpeg',
      ),
      throwsA(isA<SettingsRepositoryFailure>()),
    );
    expect(previous.profileImageRef, 'old.jpg');
    api.close();
  });
}
