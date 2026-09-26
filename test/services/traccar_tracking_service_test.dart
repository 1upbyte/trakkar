import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/login_details.dart';
import 'package:trakkar/services/tracking/traccar_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('traccar_client_sdk');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'configures the official SDK for the client URL and reports failure safely',
    () async {
      final calls = <MethodCall>[];
      var connectionWorks = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'requestPosition') return connectionWorks;
            return null;
          });
      final service = TraccarTrackingService(
        storage: const FlutterSecureStorage(),
      );
      const details = LoginDetailsDraft(
        username: 'tracker-user',
        password: 'tracker-password',
        clientUrl: 'unvalidated client endpoint',
        managerUrl: 'https://manager.test',
        source: LoginSource.manual,
      );

      await service.configure(details);
      expect(calls.map((call) => call.method), ['init', 'setConfig']);
      expect(calls.first.arguments['serverUrl'], 'unvalidated client endpoint');
      expect(calls.first.arguments['deviceId'], isNotEmpty);

      expect(await service.requestPosition(), isFalse);
      connectionWorks = true;
      expect(await service.requestPosition(), isTrue);
      expect(calls.map((call) => call.method), [
        'init',
        'setConfig',
        'requestPosition',
        'requestPosition',
      ]);
    },
  );
}
