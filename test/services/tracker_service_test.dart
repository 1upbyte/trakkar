import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/services/tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'iOS stop reports native disable failure and still stops SDK tracking',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const live = MethodChannel('trakkar/live_tracking');
      const sdk = MethodChannel('traccar_client_sdk');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(live, (call) async {
        calls.add('native.${call.method}');
        expect(call.arguments, {'enabled': false});
        throw PlatformException(code: 'live_tracking');
      });
      messenger.setMockMethodCallHandler(sdk, (call) async {
        calls.add('sdk.${call.method}');
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(live, null);
        messenger.setMockMethodCallHandler(sdk, null);
      });

      await expectLater(
        TrackerService().stop(),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, ['native.setEnabled', 'sdk.stop']);
    },
  );

  test('reduced precision is actionable even with Always access', () {
    final health = TrackingHealth.fromMap(const {
      'locationAlways': true,
      'locationPrecise': false,
      'batteryOptimizationOkay': true,
    });
    expect(health.needsLocation, isFalse);
    expect(health.needsPreciseLocation, isTrue);
    expect(health.hasWarning, isTrue);

    final restored = TrackingHealth.fromMap(const {
      'locationAlways': true,
      'locationPrecise': true,
      'batteryOptimizationOkay': true,
    });
    expect(restored.hasWarning, isFalse);
    final android = TrackingHealth.fromMap(const {
      'locationAlways': true,
      'batteryOptimizationOkay': true,
    });
    expect(android.hasWarning, isFalse);
    expect(const TrackingHealth.unchecked().needsPreciseLocation, isFalse);
  });

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
    'iOS setup disables the SDK distance trigger to throttle uploads by time',
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
        expect(location['distanceMeters'], 0x7fffffff);
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
