import 'dart:async';

import 'package:http/http.dart' as http;

import '../../models/login_details.dart';
import '../../models/setup_attempt.dart';

sealed class AuthenticationResult {
  const AuthenticationResult();
}

class AuthenticationSuccess extends AuthenticationResult {
  const AuthenticationSuccess(this.cookie);
  final String cookie;
}

class AuthenticationFailure extends AuthenticationResult {
  const AuthenticationFailure(this.failure);
  final SetupFailure failure;
}

class TraccarAuthService {
  TraccarAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthenticationResult> authenticate(LoginDetailsDraft details) async {
    try {
      final base = Uri.parse(details.managerUrl);
      final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
      final endpoint = base.replace(path: '$basePath/api/session');
      final response = await _client
          .post(
            endpoint,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'email': details.username, 'password': details.password},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const AuthenticationFailure(
          SetupFailure(
            service: SetupService.manager,
            summary: 'The username or password was not accepted.',
            isRejectedCredentials: true,
          ),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthenticationFailure(
          SetupFailure(
            service: SetupService.manager,
            summary: 'The manager service is unavailable.',
            safeDetails:
                'The manager service returned status ${response.statusCode}.',
          ),
        );
      }

      final setCookie = response.headers['set-cookie'];
      if (setCookie == null || setCookie.isEmpty) {
        return const AuthenticationFailure(
          SetupFailure(
            service: SetupService.manager,
            summary: 'The manager service did not establish a session.',
            safeDetails:
                'No session cookie was returned by the manager service.',
          ),
        );
      }
      return AuthenticationSuccess(setCookie.split(';').first);
    } on TimeoutException {
      return const AuthenticationFailure(
        SetupFailure(
          service: SetupService.manager,
          summary: 'The manager service is unavailable.',
          safeDetails: 'The manager service request timed out.',
        ),
      );
    } on Object {
      return const AuthenticationFailure(
        SetupFailure(
          service: SetupService.manager,
          summary: 'The manager service is unavailable.',
          safeDetails: 'The manager service request could not be completed.',
        ),
      );
    }
  }

  void close() => _client.close();
}
