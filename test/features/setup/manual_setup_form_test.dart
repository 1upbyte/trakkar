import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/features/setup/manual_setup_screen.dart';
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
  testWidgets('requires all four non-empty values and keeps password masked', (
    tester,
  ) async {
    var requests = 0;
    final store = MemorySessionStore();
    final controller = SetupController(
      service: TraccarAuthService(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            '',
            200,
            headers: {'set-cookie': 'JSESSIONID=manual; Path=/'},
          );
        }),
      ),
      store: store,
    );
    controller.beginManualEntry();
    await tester.pumpWidget(
      MaterialApp(home: ManualSetupScreen(controller: controller)),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(4));
    expect(requests, 0);
    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(1)).obscureText,
      isTrue,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'name');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.enterText(find.byType(TextFormField).at(2), 'not a URL');
    await tester.enterText(find.byType(TextFormField).at(3), 'also not a URL');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(controller.hasAuthenticatedSession, isTrue);
    expect(controller.draft, isNull);
    expect(store.value?.details.clientUrl, 'not a URL');
    expect(store.value?.details.managerUrl, 'also not a URL');
    controller.dispose();
  });
}
