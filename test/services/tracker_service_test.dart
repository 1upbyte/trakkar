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
    'uses time-based SDK updates without overriding the interval with distance',
    () async {
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
}
