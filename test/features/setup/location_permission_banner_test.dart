import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:trakkar/app/app_shell.dart';
import 'package:trakkar/models/login_details.dart';
import 'package:trakkar/services/auth/secure_session_store.dart';
import 'package:trakkar/services/auth/setup_controller.dart';
import 'package:trakkar/services/auth/traccar_auth_service.dart';

class _MemorySessionStore implements SessionStore {
  @override
  Future<void> save(LoginDetailsDraft details, String cookie) async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('shows location banner until Always and Precise are granted', (
    tester,
  ) async {
    var granted = false;
    final controller = SetupController(
      service: TraccarAuthService(
        client: MockClient((_) async => throw StateError('unused')),
      ),
      store: _MemorySessionStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          controller: controller,
          locationAccessCheck: () async => granted,
          onRequestLocationAccess: () async => granted = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Always and Precise location permission is needed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Re-ask'));
    await tester.pumpAndSettle();
    expect(
      find.text('Always and Precise location permission is needed.'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
