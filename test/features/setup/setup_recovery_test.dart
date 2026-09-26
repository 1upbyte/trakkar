import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/app/app_router.dart';
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

const details = LoginDetailsDraft(
  username: 'secret-user',
  password: 'secret-password',
  clientUrl: 'http://client.test',
  managerUrl: 'http://manager.test',
  source: LoginSource.manual,
);

void main() {
  testWidgets(
    'rejected credentials offer Back, Retry, Proceed Anyway; Back retains details',
    (tester) async {
      var requests = 0;
      final controller = SetupController(
        service: TraccarAuthService(
          client: MockClient((_) async {
            requests++;
            return http.Response('do not show this', 401);
          }),
        ),
        store: MemorySessionStore(),
      );
      await controller.authenticate(details);
      controller.isRestoringSession = false;
      await tester.pumpWidget(
        MaterialApp(home: AppRouter(controller: controller)),
      );

      expect(
        find.text('The username or password was not accepted.'),
        findsOneWidget,
      );
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Proceed Anyway'), findsOneWidget);
      expect(find.text('View full error'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(
        find.text('The username or password was not accepted.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Details'), findsOneWidget);
      expect(find.text('secret-user'), findsOneWidget);
      final passwordField = tester.widget<EditableText>(
        find.byType(EditableText).at(1),
      );
      expect(passwordField.controller.text, 'secret-password');
      expect(passwordField.obscureText, isTrue);
      expect(requests, 2);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('unavailable service reveals only safe details on request', (
    tester,
  ) async {
    final controller = SetupController(
      service: TraccarAuthService(
        client: MockClient(
          (_) async => http.Response('secret response body', 503),
        ),
      ),
      store: MemorySessionStore(),
    );
    await controller.authenticate(details);
    controller.isRestoringSession = false;
    await tester.pumpWidget(
      MaterialApp(home: AppRouter(controller: controller)),
    );

    expect(find.text('Manager service is unavailable.'), findsOneWidget);
    expect(find.text('secret response body'), findsNothing);
    await tester.tap(find.text('View full error'));
    await tester.pump();
    expect(
      find.text('The manager service returned status 503.'),
      findsOneWidget,
    );
    expect(find.text('secret-password'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Proceed Anyway opens map without creating a session', (
    tester,
  ) async {
    final controller = SetupController(
      service: TraccarAuthService(
        client: MockClient((_) async => http.Response('', 401)),
      ),
      store: MemorySessionStore(),
    );
    await controller.authenticate(details);
    controller.isRestoringSession = false;
    await tester.pumpWidget(
      MaterialApp(home: AppRouter(controller: controller)),
    );
    await tester.tap(find.text('Proceed Anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Map'), findsOneWidget);
    expect(controller.hasAuthenticatedSession, isFalse);
    expect(find.text('Connection to server failed'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('unavailable service keeps the server retry bar on the map', (
    tester,
  ) async {
    var requests = 0;
    final controller = SetupController(
      service: TraccarAuthService(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 503);
        }),
      ),
      store: MemorySessionStore(),
    );
    await controller.authenticate(details);
    controller.isRestoringSession = false;
    await tester.pumpWidget(
      MaterialApp(home: AppRouter(controller: controller)),
    );
    await tester.tap(find.text('Proceed Anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Connection to server failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(controller.hasAuthenticatedSession, isFalse);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Manager service is unavailable.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test(
    'ignores concurrent authentication and persists only a successful session',
    () async {
      final response = Completer<http.Response>();
      var requests = 0;
      final store = MemorySessionStore();
      final controller = SetupController(
        service: TraccarAuthService(
          client: MockClient((_) {
            requests++;
            return response.future;
          }),
        ),
        store: store,
      );

      final first = controller.authenticate(details);
      await Future<void>.delayed(Duration.zero);
      await controller.authenticate(details);
      expect(requests, 1);
      expect(store.value, isNull);

      response.complete(
        http.Response(
          '',
          200,
          headers: {'set-cookie': 'JSESSIONID=secure; Path=/'},
        ),
      );
      await first;
      expect(controller.hasAuthenticatedSession, isTrue);
      expect(controller.draft, isNull);
      expect(store.value?.details.username, details.username);
      expect(store.value?.cookie, 'JSESSIONID=secure');
      controller.dispose();
    },
  );

  test(
    'restores persisted credentials by reauthenticating before showing the map',
    () async {
      final store = MemorySessionStore()
        ..value = StoredSession(details: details, cookie: 'old-session');
      var requests = 0;
      final controller = SetupController(
        service: TraccarAuthService(
          client: MockClient((_) async {
            requests++;
            return http.Response(
              '',
              200,
              headers: {'set-cookie': 'JSESSIONID=refreshed; Path=/'},
            );
          }),
        ),
        store: store,
      );

      await controller.restoreSession();
      expect(requests, 1);
      expect(controller.isRestoringSession, isFalse);
      expect(controller.hasAuthenticatedSession, isTrue);
      expect(controller.draft, isNull);
      expect(store.value?.cookie, 'JSESSIONID=refreshed');
      controller.dispose();
    },
  );
}
