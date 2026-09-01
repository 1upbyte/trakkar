import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/services/tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'configures frequent SDK updates while retaining stop detection',
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
      final config = Map<String, dynamic>.from(calls.last.arguments as Map);
      final location = Map<String, dynamic>.from(config['location'] as Map);
      expect(location['distanceMeters'], 25);
      expect(location['intervalSeconds'], 30);
      expect(location['stopDetection'], isTrue);
    },
  );
}
