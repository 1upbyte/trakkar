import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../models/person.dart';
import '../models/saved_place.dart';

class TraccarMapSnapshot {
  const TraccarMapSnapshot({
    required this.people,
    required this.places,
    required this.mapTilerKey,
  });

  final List<PersonMapEntry> people;
  final List<SavedPlace> places;
  final String? mapTilerKey;
}

class TraccarMapUpdate {
  const TraccarMapUpdate({this.devices = const [], this.positions = const []});
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> positions;
}

class TraccarDataFailure implements Exception {
  const TraccarDataFailure();
  @override
  String toString() => 'The server request could not be completed.';
}

class TraccarDataRepository {
  TraccarDataRepository({
    required this.managerUrl,
    required this.sessionCookie,
    http.Client? client,
    WebSocketChannel Function(Uri uri, Map<String, dynamic> headers)?
    socketConnector,
  }) : _client = client ?? http.Client(),
       _socketConnector = socketConnector ?? _connectSocket;

  final String managerUrl;
  final String sessionCookie;
  final http.Client _client;
  final WebSocketChannel Function(Uri, Map<String, dynamic>) _socketConnector;
  WebSocketChannel? _channel;

  static WebSocketChannel _connectSocket(
    Uri uri,
    Map<String, dynamic> headers,
  ) => IOWebSocketChannel.connect(uri, headers: headers);

  Future<TraccarMapSnapshot> loadMap() async {
    try {
      final results = await Future.wait([
        _getList('/api/devices'),
        _getList('/api/positions'),
        _getList('/api/geofences'),
        _getObject('/api/server'),
      ]);
      final positions = {
        for (final position in results[1] as List<Map<String, dynamic>>)
          if (position['deviceId'] != null)
            (position['deviceId'] as num).toInt(): position,
      };
      final people = (results[0] as List<Map<String, dynamic>>)
          .map(
            (device) => PersonMapEntry.fromTraccar(
              device: device,
              position: positions[(device['id'] as num?)?.toInt()],
            ),
          )
          .toList();
      final places = (results[2] as List<Map<String, dynamic>>)
          .map(SavedPlace.fromTraccar)
          .whereType<SavedPlace>()
          .toList();
      final server = results[3] as Map<String, dynamic>;
      final attributes = server['attributes'];
      final key = attributes is Map ? attributes['trakkarMapTilerKey'] : null;
      return TraccarMapSnapshot(
        people: people,
        places: places,
        mapTilerKey: key is String && key.isNotEmpty ? key : null,
      );
    } on TraccarDataFailure {
      rethrow;
    } on Object {
      throw const TraccarDataFailure();
    }
  }

  Future<List<SavedPlace>> loadGeofences() async {
    try {
      return (await _getList('/api/geofences'))
          .map(SavedPlace.fromTraccar)
          .whereType<SavedPlace>()
          .toList();
    } on TraccarDataFailure {
      rethrow;
    } on Object {
      throw const TraccarDataFailure();
    }
  }

  Future<void> createGeofence({
    required String name,
    required String area,
  }) async {
    try {
      final response = await _client
          .post(
            _apiUri('/api/geofences'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'area': area}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const TraccarDataFailure();
      }
    } on TraccarDataFailure {
      rethrow;
    } on Object {
      throw const TraccarDataFailure();
    }
  }

  Future<void> deleteGeofence(int id) async {
    try {
      final response = await _client
          .delete(_apiUri('/api/geofences/$id'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const TraccarDataFailure();
      }
    } on TraccarDataFailure {
      rethrow;
    } on Object {
      throw const TraccarDataFailure();
    }
  }

  Future<String?> reverseGeocode(LatLng point) async {
    try {
      final uri = _apiUri('/api/server/geocode').replace(
        queryParameters: {
          'latitude': point.latitude.toString(),
          'longitude': point.longitude.toString(),
        },
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const TraccarDataFailure();
      }
      return response.body;
    } on Object {
      throw const TraccarDataFailure();
    }
  }

  Future<Uint8List> loadProfileImage(String imageRef) async {
    try {
      final uri = imageRef.startsWith('traccar-media:')
          ? _apiUri('/api/media/${imageRef.substring('traccar-media:'.length)}')
          : _resolveImageReference(imageRef);
      final sameServer = uri.origin == Uri.parse(managerUrl).origin;
      final response = await _client
          .get(
            uri,
            headers: sameServer ? _headers : const {'Accept': 'image/*'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const TraccarDataFailure();
      }
      return response.bodyBytes;
    } on Object {
      throw const TraccarDataFailure();
    }
  }

  Uri _resolveImageReference(String imageRef) {
    final reference = Uri.parse(imageRef);
    if (reference.hasScheme) return reference;
    final base = Uri.parse(managerUrl);
    return base.resolve(imageRef);
  }

  Stream<TraccarMapUpdate> watchUpdates({
    required void Function() onFailure,
  }) async* {
    try {
      final uri = _apiUri('/api/socket');
      final socketUri = uri.replace(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      );
      final channel = _socketConnector(socketUri, _headers);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 15));
      await for (final message in channel.stream) {
        final decoded = jsonDecode(message as String);
        if (decoded is! Map<String, dynamic>) continue;
        yield TraccarMapUpdate(
          devices: _objectList(decoded['devices']),
          positions: _objectList(decoded['positions']),
        );
      }
      onFailure();
    } on Object {
      onFailure();
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await _client
        .get(_apiUri(path), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const TraccarDataFailure();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const TraccarDataFailure();
    return _objectList(decoded);
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final response = await _client
        .get(_apiUri(path), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const TraccarDataFailure();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const TraccarDataFailure();
    return decoded;
  }

  Uri _apiUri(String path) {
    final base = Uri.parse(managerUrl);
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$basePath$path', query: null, fragment: null);
  }

  Map<String, String> get _headers => {
    'Cookie': sessionCookie,
    'Accept': 'application/json',
  };

  Future<void> close() async {
    await _channel?.sink.close();
    _client.close();
  }
}

List<Map<String, dynamic>> _objectList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];
