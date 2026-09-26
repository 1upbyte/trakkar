import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trakkar/models/login_details.dart';
import 'package:trakkar/models/setup_attempt.dart';
import 'package:trakkar/services/auth/traccar_auth_service.dart';

void main() {
  const details = LoginDetailsDraft(
    username: 'private-user',
    password: 'private-password',
    clientUrl: 'http://client.test',
    managerUrl: 'https://manager.test',
    source: LoginSource.manual,
  );

  test(
    'posts credentials as form fields and returns the session cookie',
    () async {
      late http.Request captured;
      final service = TraccarAuthService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '',
            200,
            headers: {'set-cookie': 'JSESSIONID=abc; Path=/'},
          );
        }),
      );

      final result = await service.authenticate(details);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/session');
      expect(captured.bodyFields, {
        'email': 'private-user',
        'password': 'private-password',
      });
      expect((result as AuthenticationSuccess).cookie, 'JSESSIONID=abc');
    },
  );

  test(
    'classifies rejected credentials without echoing submitted secrets',
    () async {
      final service = TraccarAuthService(
        client: MockClient((_) async => http.Response('secret body', 401)),
      );

      final failure = (await service.authenticate(
        details,
      ) as AuthenticationFailure).failure;
      expect(failure.isRejectedCredentials, isTrue);
      expect(failure.summary, isNot(contains('private')));
      expect(failure.safeDetails, isNull);
    },
  );

  test('classifies service failures with safe opt-in details', () async {
    final service = TraccarAuthService(
      client: MockClient((_) async => http.Response('secret body', 503)),
    );

    final failure =
        (await service.authenticate(details) as AuthenticationFailure).failure;
    expect(failure.service, SetupService.manager);
    expect(failure.safeDetails, contains('503'));
    expect(failure.safeDetails, isNot(contains('private')));
  });

  test('does not expose transport errors or URL user-info', () async {
    final service = TraccarAuthService(
      client: MockClient((_) async {
        throw http.ClientException(
          'private-password',
          Uri.parse('https://private-user:private-password@manager.test'),
        );
      }),
    );

    final failure =
        (await service.authenticate(details) as AuthenticationFailure).failure;
    expect(failure.service, SetupService.manager);
    expect(failure.isRejectedCredentials, isFalse);
    expect(failure.summary, isNot(contains('private')));
    expect(failure.safeDetails, isNot(contains('private')));
  });
}
