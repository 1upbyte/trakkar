import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/services/tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tracking health reports each actionable platform issue', () {
    final health = TrackingHealth.fromMap(const {
      'locationAlways': false,
      'activityRecognitionOkay': false,
      'batteryOptimizationOkay': false,
      'batteryOptimizationRelevant': true,
    });

    expect(health.checked, isTrue);
    expect(health.needsLocation, isTrue);
    expect(health.needsActivity, isTrue);
    expect(health.needsBattery, isTrue);
    expect(health.hasWarning, isTrue);
  });

  test(
    'non-Android setup keeps time-based SDK updates without a distance filter',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('traccar_client_sdk');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await TrackerService().configure(
        serverUrl: Uri.parse('https://client.example.com'),
        deviceId: 'pablo',
      );

      expect(calls.map((call) => call.method), ['init', 'setConfig']);
      for (final call in calls) {
        final config = Map<String, dynamic>.from(call.arguments as Map);
        final location = Map<String, dynamic>.from(config['location'] as Map);
        expect(location['accuracy'], 'MEDIUM');
        // A positive distance would make SDK 1.0.11 use a zero interval.
        expect(location['distanceMeters'], 0);
        expect(location['intervalSeconds'], 600);
        expect(location['stopDetection'], isTrue);
        expect(location['stopTimeoutSeconds'], 120);
        expect(location['stationaryRadiusMeters'], 100);
      }
    },
  );

  test('Android configures through one native path without rebuilding the SDK twice', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const sdk = MethodChannel('traccar_client_sdk');
    const live = MethodChannel('trakkar/live_tracking');
    final calls = <String>[];
    final connections = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sdk, (call) async {
      calls.add('sdk.${call.method}');
      return null;
    });
    messenger.setMockMethodCallHandler(live, (call) async {
      calls.add('native.${call.method}');
      connections.add(call.arguments);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(sdk, null);
      messenger.setMockMethodCallHandler(live, null);
    });

    final service = TrackerService();
    await service.configure(
      serverUrl: Uri.parse('https://client.test'),
      deviceId: 'first',
    );
    await service.configure(
      serverUrl: Uri.parse('https://replacement.test'),
      deviceId: 'second',
    );

    expect(calls, ['native.configure', 'native.configure']);
    expect(connections, [
      {'serverUrl': 'https://client.test', 'deviceId': 'first'},
      {'serverUrl': 'https://replacement.test', 'deviceId': 'second'},
    ]);
  });

  test('Android configuration failure is surfaced instead of using an old connection', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('trakkar/live_tracking');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'tracking_configuration');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await expectLater(
      TrackerService().configure(
        serverUrl: Uri.parse('https://client.test'),
        deviceId: 'phone',
      ),
      throwsA(isA<PlatformException>()),
    );
  });
}
