import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/user_profile.dart';

class SettingsRepositoryFailure implements Exception {
  const SettingsRepositoryFailure();
}

class SettingsApiClient {
  SettingsApiClient({
    required this.managerUrl,
    required this.sessionCookie,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String managerUrl;
  final String sessionCookie;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Cookie': sessionCookie,
    'Accept': 'application/json',
  };

  Uri _uri(String path) {
    final base = Uri.parse(managerUrl);
    final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$prefix$path', query: null, fragment: null);
  }

  Future<Map<String, dynamic>> getObject(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 20));
    _check(response.statusCode);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const SettingsRepositoryFailure();
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 20));
    _check(response.statusCode);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const SettingsRepositoryFailure();
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> putObject(
    String path,
    Map<String, dynamic> value,
  ) async {
    final response = await _client
        .put(
          _uri(path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(value),
        )
        .timeout(const Duration(seconds: 20));
    _check(response.statusCode);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const SettingsRepositoryFailure();
    }
    return decoded;
  }

  Future<String> uploadImage(
    int deviceId,
    List<int> bytes,
    String contentType,
  ) async {
    if (!const {
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
    }.contains(contentType)) {
      throw const SettingsRepositoryFailure();
    }
    final response = await _client
        .post(
          _uri('/api/devices/$deviceId/image'),
          headers: {..._headers, 'Content-Type': contentType},
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));
    _check(response.statusCode);
    final filename = response.body.trim().replaceAll('"', '');
    if (filename.isEmpty || filename.contains('/') || filename.contains('\\')) {
      throw const SettingsRepositoryFailure();
    }
    return filename;
  }

  void _check(int statusCode) {
    if (statusCode < 200 || statusCode >= 300) {
      throw const SettingsRepositoryFailure();
    }
  }

  void close() => _client.close();
}

abstract interface class ProfileRepository {
  Future<UserProfile> loadProfile();
  Future<UserProfile> updateDisplayName(String value);
}

class TraccarProfileRepository implements ProfileRepository {
  const TraccarProfileRepository(this._api);

  final SettingsApiClient _api;

  @override
  Future<UserProfile> loadProfile() async {
    final user = await _api.getObject('/api/session');
    final profile = UserProfile.fromTraccar(user);
    if (profile == null) throw const SettingsRepositoryFailure();
    return profile;
  }

  @override
  Future<UserProfile> updateDisplayName(String value) async {
    final name = value.trim();
    if (name.isEmpty) throw ArgumentError.value(value, 'value');
    final existing = await _api.getObject('/api/session');
    final id = (existing['id'] as num?)?.toInt();
    if (id == null) throw const SettingsRepositoryFailure();
    final response = await _api.putObject('/api/users/$id', {
      ...existing,
      'name': name,
    });
    final profile = UserProfile.fromTraccar(response);
    if (profile == null) throw const SettingsRepositoryFailure();
    return profile;
  }
}
