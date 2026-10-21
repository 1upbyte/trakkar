import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/io.dart';

import '../models/provisioning_config.dart';
import '../models/named_place.dart';
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

  /// Used only for authenticating the companion live-tracking sidecar.
  String? get sessionCookie => _sessionCookie;

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

  Future<List<TraccarPosition>> positionHistory(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await _get(
      'positions',
      query: {
        'deviceId': '$deviceId',
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return _decodeList(response).map(TraccarPosition.fromJson).toList();
  }

  /// Loads the MapTiler key from Traccar's server-level attributes. Keeping
  /// the value there gives every signed-in Trakkar client the same setting and
  /// avoids persisting third-party API keys on phones.
  Future<String> mapTilerApiKey() async {
    final response = await _get('server');
    final server = _decodeObject(response);
    final attributes = Map<String, dynamic>.from(
      server['attributes'] as Map? ?? const <String, dynamic>{},
    );
    return (attributes['trakkarMapTilerKey'] as String? ?? '').trim();
  }

  Future<List<NamedPlace>> namedPlaces() async {
    final response = await _get('geofences');
    final places = <NamedPlace>[];
    for (final geofence in _decodeList(response)) {
      final attributes = Map<String, dynamic>.from(
        geofence['attributes'] as Map? ?? const <String, dynamic>{},
      );
      final marker = attributes['trakkarNamedPlace'];
      if (marker != true && marker?.toString().toLowerCase() != 'true') {
        continue;
      }
      try {
        places.add(NamedPlace.fromGeofence(geofence));
      } on FormatException {
        // Ignore malformed tagged records without hiding other shared places.
      }
    }
    return places;
  }

  Future<NamedPlace> createNamedPlace({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    List<LatLng> boundary = const <LatLng>[],
  }) async {
    final draft = NamedPlace(
      id: '0',
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      boundary: boundary,
    );
    final response = await _sendJson(
      'POST',
      'geofences',
      draft.toGeofencePayload(),
      action: 'Saving the named place',
    );
    return NamedPlace.fromGeofence(_decodeObject(response));
  }

  Future<void> deleteNamedPlace(int id) async {
    await _send(
      http.Request('DELETE', _apiUri('geofences/$id')),
      allowed: const <int>{204},
      action: 'Deleting the named place',
    );
  }

  Future<Uint8List?> deviceImage(TraccarDevice device) async {
    final imageName = device.imageName;
    if (imageName == null || !_safeMediaPart.hasMatch(device.uniqueId)) {
      return null;
    }
    if (!_safeMediaPart.hasMatch(imageName)) return null;
    final response = await _get(
      'media/${device.uniqueId}/$imageName',
      allowed: const <int>{200, 404},
    );
    return response.statusCode == 404 ? null : response.bodyBytes;
  }

  Future<TraccarDevice> uploadDeviceImage(
    TraccarDevice device,
    Uint8List bytes,
    String contentType,
  ) async {
    const supported = <String>{
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
    };
    if (!supported.contains(contentType)) {
      throw const TraccarApiException(
        'Choose a JPEG, PNG, GIF, or WebP profile picture.',
      );
    }
    if (bytes.length > 500000) {
      throw const TraccarApiException(
        'The profile picture must be smaller than 500 KB.',
      );
    }
    final request = http.Request('POST', _apiUri('devices/${device.id}/image'))
      ..headers['Content-Type'] = contentType
      ..bodyBytes = bytes;
    final upload = await _send(
      request,
      allowed: const <int>{200},
      action: 'Uploading the profile picture',
    );
    final fileName = upload.body.trim().replaceAll('"', '');
    if (!_safeMediaPart.hasMatch(fileName)) {
      throw const TraccarApiException(
        'The server returned an invalid profile picture name.',
      );
    }
    final attributes = <String, dynamic>{
      ...device.attributes,
      'deviceImage': fileName,
    };
    final update = await _sendJson(
      'PUT',
      'devices/${device.id}',
      device.updateAttributesPayload(attributes),
      action: 'Saving the profile picture',
    );
    return TraccarDevice.fromJson(_decodeObject(update));
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
    Map<String, dynamic> body, {
    String action = 'Device update',
  }) async {
    final request = http.Request(method, _apiUri(path))
      ..headers.addAll(<String, String>{'Content-Type': 'application/json'})
      ..body = jsonEncode(body);
    return _send(request, allowed: const <int>{200}, action: action);
  }

  Future<http.Response> _send(
    http.Request request, {
    required Set<int> allowed,
    required String action,
  }) async {
    _requireSession();
    request.headers['Cookie'] = _sessionCookie!;
    final streamed = await _guardRequest(
      () => _client.send(request).timeout(_requestTimeout),
    );
    final response = await http.Response.fromStream(streamed)
        .timeout(_requestTimeout);
    _expect(response, allowed, action: action);
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

  static final RegExp _safeMediaPart = RegExp(r'^[A-Za-z0-9._-]+$');

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
