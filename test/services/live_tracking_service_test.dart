import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/services/traccar_api.dart';
import 'package:trakkar/services/tracking/live_tracking_service.dart';

void main() {
  const channel = MethodChannel('trakkar/live_tracking');
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('renews only while visible and releases when hidden', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final native = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          native.add(call);
          return call.method == 'pushToken' ? 'native-push-token' : null;
        });
    final service = LiveTrackingService(
      sessionCookie: 'JSESSIONID=test',
      uniqueId: 'local-phone',
      endpoint: 'https://live.test',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.url.path == '/v1/devices'
              ? '{"deviceId":12,"deviceToken":"scoped-device-token"}'
              : '{}',
          200,
        );
      }),
    );
    service.setDevices([12, 13, 13]);
    await tester.pump();
    expect(requests, isEmpty);
    service.setVisible(true);
    await tester.pump();
    expect(requests.map((r) => r.method), ['POST', 'PUT']);
    expect(jsonDecode(requests.last.body)['deviceIds'], [12, 13]);
    expect(requests.first.headers['X-Traccar-Session'], 'JSESSIONID=test');
    expect(native.any((call) => call.method == 'register'), isTrue);
    expect(native.where((call) => call.method == 'reconcile').length, 1);
    await tester.pump(const Duration(seconds: 15));
    expect(requests.where((r) => r.method == 'PUT').length, 2);
    expect(requests.where((r) => r.method == 'POST').length, 1);
    expect(native.where((call) => call.method == 'reconcile').length, 2);
    service.setVisible(false);
    await tester.pump();
    expect(requests.last.method, 'DELETE');
    await tester.pump(const Duration(seconds: 45));
    expect(requests.where((r) => r.method == 'PUT').length, 2);
    expect(native.where((call) => call.method == 'reconcile').length, 2);
    service.dispose();
  });

  testWidgets('failed view renewal does not activate native live tracking', (
    tester,
  ) async {
    final native = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          native.add(call);
          return call.method == 'pushToken' ? 'native-push-token' : null;
        });
    final service = LiveTrackingService(
      sessionCookie: 'JSESSIONID=test',
      uniqueId: 'local-phone',
      endpoint: 'https://live.test',
      client: MockClient((request) async {
        return request.method == 'POST'
            ? http.Response('{"deviceId":12,"deviceToken":"scoped-token"}', 200)
            : http.Response('{}', 503);
      }),
    );
    service.setDevices([12]);
    service.setVisible(true);
    await tester.pump();
    expect(native.any((call) => call.method == 'register'), isTrue);
    expect(native.any((call) => call.method == 'reconcile'), isFalse);
    service.dispose();
  });

  testWidgets('missing endpoint makes no platform or network requests', (
    tester,
  ) async {
    final service = LiveTrackingService(
      sessionCookie: 'unused',
      uniqueId: 'unused',
      endpoint: '',
      client: MockClient((_) => throw StateError('unexpected request')),
    );
    service.setDevices([1]);
    service.setVisible(true);
    await service.claim(replace: true);
    await service.register();
    await tester.pump(const Duration(seconds: 60));
    service.dispose();
  });
  testWidgets('concurrent setup and map renewal register a device only once', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var registrations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'pushToken' ? 'native-token' : null,
        );
    final service = LiveTrackingService(
      sessionCookie: 'JSESSIONID=test',
      uniqueId: 'username',
      endpoint: 'https://live.test',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          registrations++;
          return response.future;
        }
        return http.Response('{}', 200);
      }),
    );
    final registration = service.register();
    service.setDevices([1]);
    service.setVisible(true);
    await tester.pump();
    expect(registrations, 1);
    response.complete(
      http.Response('{"deviceId":1,"deviceToken":"scoped-token"}', 200),
    );
    await registration;
    await tester.pump();
    expect(registrations, 1);
    service.dispose();
  });

  testWidgets(
    'onboarding claims without a push token and remembers the installation',
    (tester) async {
      final requests = <http.Request>[];
      var pushToken = 'initial-push-token';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return call.method == 'pushToken' ? pushToken : null;
          });
      LiveTrackingService create() => LiveTrackingService(
        sessionCookie: 'JSESSIONID=test',
        uniqueId: 'username',
        endpoint: 'https://live.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.url.path == '/v1/devices/claim'
                ? '{"deviceId":12}'
                : '{"deviceId":12,"deviceToken":"device-token"}',
            200,
          );
        }),
      );
      final onboarding = create();
      await onboarding.claim(replace: true);
      expect(requests.single.url.path, '/v1/devices/claim');
      final claim = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(claim['replace'], isTrue);
      expect(
        claim['installationToken'],
        matches(RegExp(r'^[A-Za-z0-9_-]{43}$')),
      );
      expect(claim.containsKey('pushToken'), isFalse);
      onboarding.dispose();

      final reconnected = create();
      await reconnected.register();
      pushToken = 'refreshed-push-token';
      await reconnected.register();
      await reconnected.unregister();
      for (final request in requests.skip(1)) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['installationToken'], claim['installationToken']);
        expect(body.containsKey('replace'), isFalse);
      }
      expect(requests.last.method, 'DELETE');
      reconnected.dispose();
    },
  );

  testWidgets(
    'failed takeover is reported instead of silently completing onboarding',
    (tester) async {
      final service = LiveTrackingService(
        sessionCookie: 'JSESSIONID=test',
        uniqueId: 'username',
        endpoint: 'https://live.test',
        client: MockClient((_) async => http.Response('{}', 409)),
      );
      await expectLater(
        service.claim(),
        throwsA(
          isA<TraccarApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
      service.dispose();
    },
  );
}
