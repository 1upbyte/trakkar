import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import '../models/provisioning_config.dart';
import '../models/traccar_device.dart';
import '../models/traccar_position.dart';

class TraccarApiException implements Exception {
  const TraccarApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TraccarApi {
  TraccarApi({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  final ProvisioningConfig config;
  final http.Client _client;
  String? _sessionCookie;

  static const _requestTimeout = Duration(seconds: 15);

  bool get hasSession => _sessionCookie != null;

  Future<void> login() async {
    final response = await _guardRequest(
      () => _client
          .post(
            _apiUri('session'),
            headers: const <String, String>{
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: <String, String>{
              'email': config.managerUsername,
              'password': config.managerPassword,
            },
          )
          .timeout(_requestTimeout),
    );
    _expect(response, <int>{200}, action: 'Sign in');
    final setCookie = response.headers['set-cookie'] ?? '';
    final match = RegExp(r'(JSESSIONID=[^;,\s]+)').firstMatch(setCookie);
    if (match == null) {
      throw const TraccarApiException(
        'The manager server did not return a Traccar session cookie.',
      );
    }
    _sessionCookie = match.group(1);
  }

  Future<List<TraccarDevice>> devices() async {
    final response = await _get('devices');
    return _decodeList(response)
        .map(TraccarDevice.fromJson)
        .toList(growable: false);
  }

  Future<TraccarDevice?> findDevice(String uniqueId) async {
    var response = await _get(
      'devices',
      query: <String, String>{'uniqueId': uniqueId, 'all': 'true'},
      allowed: <int>{200, 400},
    );
    if (response.statusCode == 400) {
      response = await _get(
        'devices',
        query: <String, String>{'uniqueId': uniqueId},
      );
    }
    final matches = _decodeList(response).map(TraccarDevice.fromJson).toList();
    return matches.isEmpty ? null : matches.first;
  }

  Future<TraccarDevice> createDevice({
    required String name,
    required String uniqueId,
  }) async {
    final response = await _sendJson('POST', 'devices', <String, dynamic>{
      'id': 0,
      'name': name,
      'uniqueId': uniqueId,
      'disabled': false,
      'attributes': <String, dynamic>{},
    });
    return TraccarDevice.fromJson(_decodeObject(response));
  }

  Future<TraccarDevice> updateDeviceName(
    TraccarDevice device,
    String name,
  ) async {
    final response = await _sendJson(
      'PUT',
      'devices/${device.id}',
      device.updatePayload(displayName: name),
    );
    return TraccarDevice.fromJson(_decodeObject(response));
  }

  Future<List<TraccarPosition>> positions() async {
    final response = await _get('positions');
    return _decodeList(response)
        .map(TraccarPosition.fromJson)
        .toList(growable: false);
  }

  Future<String> reverseGeocode(double latitude, double longitude) async {
    final response = await _get(
      'server/geocode',
      query: <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );
    return response.body.trim();
  }

  Stream<Map<String, dynamic>> liveUpdates() async* {
    final cookie = _sessionCookie;
    if (cookie == null) {
      throw const TraccarApiException('Sign in before opening live updates.');
    }
    final channel = IOWebSocketChannel.connect(
      _socketUri(),
      headers: <String, String>{'Cookie': cookie},
      pingInterval: const Duration(seconds: 30),
    );
    try {
      await channel.ready;
      await for (final event in channel.stream) {
        late final Object? decoded;
        try {
          decoded = jsonDecode(event as String);
        } on Object {
          throw const TraccarApiException(
            'The manager server sent an unexpected live update.',
          );
        }
        if (decoded is Map<String, dynamic>) {
          yield decoded;
        } else if (decoded is Map) {
          yield Map<String, dynamic>.from(decoded);
        }
      }
    } finally {
      await channel.sink.close();
    }
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
    Set<int> allowed = const <int>{200},
  }) async {
    _requireSession();
    final response = await _guardRequest(
      () => _client
          .get(
            _apiUri(path, query: query),
            headers: <String, String>{'Cookie': _sessionCookie!},
          )
          .timeout(_requestTimeout),
    );
    _expect(response, allowed, action: 'Server request');
    return response;
  }

  Future<http.Response> _sendJson(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    _requireSession();
    final request = http.Request(method, _apiUri(path))
      ..headers.addAll(<String, String>{
        'Cookie': _sessionCookie!,
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(body);
    final streamed = await _guardRequest(
      () => _client.send(request).timeout(_requestTimeout),
    );
    final response = await http.Response.fromStream(streamed)
        .timeout(_requestTimeout);
    _expect(response, <int>{200}, action: 'Device update');
    return response;
  }

  Uri _apiUri(String path, {Map<String, String>? query}) {
    final base = config.managerUrl;
    var basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    if (!basePath.endsWith('/api')) {
      basePath = '$basePath/api';
    }
    return base.replace(
      path: '$basePath/${path.replaceFirst(RegExp(r'^/+'), '')}',
      queryParameters: query,
      fragment: '',
    );
  }

  Uri _socketUri() {
    final httpUri = _apiUri('socket');
    return httpUri.replace(scheme: httpUri.scheme == 'https' ? 'wss' : 'ws');
  }

  void _requireSession() {
    if (_sessionCookie == null) {
      throw const TraccarApiException('The manager session is not connected.');
    }
  }

  static List<Map<String, dynamic>> _decodeList(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(growable: false);
    } on Object {
      throw const TraccarApiException(
        'The manager server returned an unexpected response.',
      );
    }
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on Object {
      throw const TraccarApiException(
        'The manager server returned an unexpected response.',
      );
    }
  }

  static void _expect(
    http.Response response,
    Set<int> allowed, {
    required String action,
  }) {
    if (allowed.contains(response.statusCode)) {
      return;
    }
    final message = switch (response.statusCode) {
      400 =>
        '$action was rejected. Check the entered details and account permissions.',
      401 => 'The manager username or password is incorrect.',
      403 => 'The manager account does not have permission for this action.',
      404 when action == 'Sign in' =>
        'No Traccar server was found at the manager URL.',
      404 => 'The requested Traccar feature was not found on this server.',
      409 => 'That device username is already in use.',
      429 => 'Too many requests. Wait a moment and try again.',
      >= 500 => 'The Traccar server is temporarily unavailable.',
      _ => '$action failed. Check the server settings and try again.',
    };
    throw TraccarApiException(message, statusCode: response.statusCode);
  }

  static Future<T> _guardRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const TraccarApiException(
        'The server took too long to respond. Check the URL and connection.',
      );
    } on http.ClientException {
      throw const TraccarApiException(
        'Could not reach the server. Check the URL and your connection.',
      );
    }
  }

  void close() => _client.close();
}
