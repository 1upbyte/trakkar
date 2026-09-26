import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/features/setup/qr_scan_screen.dart';
import 'package:trakkar/models/login_details.dart';
import 'package:trakkar/services/auth/secure_session_store.dart';
import 'package:trakkar/services/auth/setup_controller.dart';
import 'package:trakkar/services/auth/traccar_auth_service.dart';

class MemorySessionStore implements SessionStore {
  StoredSession? value;

  @override
  Future<void> save(LoginDetailsDraft details, String cookie) async {
    value = StoredSession(details: details, cookie: cookie);
  }

  @override
  Future<StoredSession?> read() async => value;

  @override
  Future<void> clear() async => value = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(permissions, (call) async {
        if (call.method == 'checkPermissionStatus') return 0;
        if (call.method == 'requestPermissions') return <int, int>{1: 1};
        return false;
      });

  final payload = base64.encode(
    utf8.encode('qr-user;qr-password;https://client.test;https://manager.test'),
  );

  testWidgets(
    'valid scan submits immediately and persists after authentication',
    (tester) async {
      http.Request? request;
      var requests = 0;
      final store = MemorySessionStore();
      final controller = SetupController(
        service: TraccarAuthService(
          client: MockClient((value) async {
            requests++;
            request = value;
            return http.Response(
              '',
              200,
              headers: {'set-cookie': 'JSESSIONID=qr; Path=/'},
            );
          }),
        ),
        store: store,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => QrScanScreen(
                      controller: controller,
                      scannerBuilder: (_, onScan) => TextButton(
                        onPressed: () => onScan(payload),
                        child: const Text('Fake Scan'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open scanner'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fake Scan'));
      await tester.pumpAndSettle();

      expect(requests, 1);
      expect(request?.bodyFields, {
        'email': 'qr-user',
        'password': 'qr-password',
      });
      expect(controller.hasAuthenticatedSession, isTrue);
      expect(store.value?.details.clientUrl, 'https://client.test');
      expect(find.text('Confirm'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('invalid scan shows recovery choices and sends no request', (
    tester,
  ) async {
    var requests = 0;
    final controller = SetupController(
      service: TraccarAuthService(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 401);
        }),
      ),
      store: MemorySessionStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => QrScanScreen(
                    controller: controller,
                    scannerBuilder: (_, onScan) => TextButton(
                      onPressed: () => onScan('%%%'),
                      child: const Text('Fake Scan'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open scanner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fake Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid QR code'), findsOneWidget);
    expect(requests, 0);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Enter Details'), findsNWidgets(2));
    await tester.tap(find.text('Enter Details').last);
    await tester.pumpAndSettle();
    expect(controller.state.name, 'editing');
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('canceling scan offers another scan or manual entry', (
    tester,
  ) async {
    final controller = SetupController(
      service: TraccarAuthService(
        client: MockClient((_) async => http.Response('', 401)),
      ),
      store: MemorySessionStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => QrScanScreen(
                    controller: controller,
                    scannerBuilder: (_, _) =>
                        const Center(child: Text('Scanner ready')),
                  ),
                ),
              ),
              child: const Text('Open scanner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cancel scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Again'), findsNWidgets(2));
    expect(find.text('Enter Details'), findsNWidgets(2));
    await tester.tap(find.text('Scan Again').last);
    await tester.pumpAndSettle();
    expect(find.text('Scanner ready'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter Details').last);
    await tester.pumpAndSettle();
    expect(controller.state.name, 'editing');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
