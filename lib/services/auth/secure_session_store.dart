import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/login_details.dart';

class StoredSession {
  const StoredSession({required this.details, required this.cookie});

  final LoginDetailsDraft details;
  final String cookie;
}

abstract interface class SessionStore {
  Future<void> save(LoginDetailsDraft details, String cookie);
  Future<StoredSession?> read();
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _keys = {
    'username': 'login.username',
    'password': 'login.password',
    'clientUrl': 'login.clientUrl',
    'managerUrl': 'login.managerUrl',
    'cookie': 'login.sessionCookie',
  };

  @override
  Future<void> save(LoginDetailsDraft details, String cookie) async {
    try {
      await Future.wait([
        _storage.write(key: _keys['username']!, value: details.username),
        _storage.write(key: _keys['password']!, value: details.password),
        _storage.write(key: _keys['clientUrl']!, value: details.clientUrl),
        _storage.write(key: _keys['managerUrl']!, value: details.managerUrl),
        _storage.write(key: _keys['cookie']!, value: cookie),
      ]);
    } on Object {
      await Future.wait(_keys.values.map((key) => _storage.delete(key: key)));
      rethrow;
    }
  }

  @override
  Future<StoredSession?> read() async {
    final values = await Future.wait(
      _keys.values.map((key) => _storage.read(key: key)),
    );
    if (values.any((value) => value == null)) return null;
    return StoredSession(
      details: LoginDetailsDraft(
        username: values[0]!,
        password: values[1]!,
        clientUrl: values[2]!,
        managerUrl: values[3]!,
        source: LoginSource.manual,
      ),
      cookie: values[4]!,
    );
  }

  @override
  Future<void> clear() =>
      Future.wait<void>(_keys.values.map((key) => _storage.delete(key: key)));
}
