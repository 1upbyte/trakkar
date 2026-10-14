import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/services/tracking/live_tracking_service.dart';

void main() {
  const channel = MethodChannel('trakkar/live_tracking');
  TestWidgetsFlutterBinding.ensureInitialized();

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
    await tester.pump(const Duration(seconds: 15));
    expect(requests.where((r) => r.method == 'PUT').length, 2);
    expect(requests.where((r) => r.method == 'POST').length, 1);
    service.setVisible(false);
    await tester.pump();
    expect(requests.last.method, 'DELETE');
    await tester.pump(const Duration(seconds: 45));
    expect(requests.where((r) => r.method == 'PUT').length, 2);
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
    await service.register();
    await tester.pump(const Duration(seconds: 60));
    service.dispose();
  });
}
