import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:trakkar/app/app_router.dart';
import 'package:trakkar/models/login_details.dart';
import 'package:trakkar/services/auth/secure_session_store.dart';
import 'package:trakkar/services/auth/setup_controller.dart';
import 'package:trakkar/services/auth/traccar_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

  testWidgets(
    'shows privacy notice before selection and asks for camera only after Scan QR',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissions, (call) async {
            calls.add(call.method);
            if (call.method == 'checkPermissionStatus') return 0;
            if (call.method == 'requestPermissions') return <int, int>{1: 0};
            return false;
          });
      final controller = SetupController(
        service: TraccarAuthService(
          client: MockClient((_) async => throw StateError('unused')),
        ),
        store: _MemorySessionStore(),
      )..isRestoringSession = false;
      await tester.pumpWidget(
        MaterialApp(home: AppRouter(controller: controller)),
      );

      expect(
        find.textContaining('Base64 is encoding, not encryption.'),
        findsOneWidget,
      );
      expect(calls, isEmpty);

      await tester.tap(find.text('Scan QR'));
      await tester.pumpAndSettle();
      expect(calls, contains('requestPermissions'));
      expect(
        find.text('Camera permission is needed to scan a QR code.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Enter Details').last);
      await tester.pumpAndSettle();
      expect(find.text('Username'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}

class _MemorySessionStore implements SessionStore {
  @override
  Future<void> save(LoginDetailsDraft details, String cookie) async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> clear() async {}
}
