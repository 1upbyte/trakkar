import 'dart:convert';

import 'package:latlong2/latlong.dart';

class NamedPlace {
  const NamedPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150,
    this.boundary = const <LatLng>[],
    this.serverBacked = false,
  });

  factory NamedPlace.fromJson(Map<String, dynamic> json) {
    return NamedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 150,
      boundary: (json['boundary'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (point) => LatLng(
              ((point as List<dynamic>)[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ),
          )
          .toList(growable: false),
      serverBacked: json['serverBacked'] as bool? ?? false,
    );
  }

  factory NamedPlace.fromGeofence(Map<String, dynamic> json) {
    final area = json['area'] as String? ?? '';
    final match = RegExp(
      r'^CIRCLE\s*\(\s*([-+0-9.eE]+)\s+([-+0-9.eE]+)\s*,\s*([-+0-9.eE]+)\s*\)$',
      caseSensitive: false,
    ).firstMatch(area);
    if (match != null) {
      return NamedPlace(
        id: (json['id'] as num).toInt().toString(),
        name: json['name'] as String? ?? 'Unnamed place',
        latitude: double.parse(match.group(1)!),
        longitude: double.parse(match.group(2)!),
        radiusMeters: double.parse(match.group(3)!),
        serverBacked: true,
      );
    }

    final polygonMatch = RegExp(
      r'^POLYGON\s*\(\(\s*(.*?)\s*\)\)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(area);
    if (polygonMatch == null) {
      throw const FormatException(
        'Named place must be a circular or polygon geofence.',
      );
    }
    final points = polygonMatch.group(1)!.split(',').map((value) {
      final coordinates = value.trim().split(RegExp(r'\s+'));
      if (coordinates.length != 2) {
        throw const FormatException('Invalid polygon coordinate.');
      }
      return LatLng(double.parse(coordinates[0]), double.parse(coordinates[1]));
    }).toList();
    if (points.length > 1 && points.first == points.last) {
      points.removeLast();
    }
    if (points.length < 3) {
      throw const FormatException('A polygon place needs at least 3 points.');
    }
    final center = _centerOf(points);
    return NamedPlace(
      id: (json['id'] as num).toInt().toString(),
      name: json['name'] as String? ?? 'Unnamed place',
      latitude: center.latitude,
      longitude: center.longitude,
      boundary: List<LatLng>.unmodifiable(points),
      serverBacked: true,
    );
  }

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final List<LatLng> boundary;
  final bool serverBacked;

  int? get serverId => int.tryParse(id);
  bool get isPolygon => boundary.isNotEmpty;

  Map<String, dynamic> toGeofencePayload() {
    final area = isPolygon
        ? 'POLYGON ((${<LatLng>[...boundary, boundary.first].map((point) => '${point.latitude} ${point.longitude}').join(', ')}))'
        : 'CIRCLE ($latitude $longitude, $radiusMeters)';
    return <String, dynamic>{
      'id': 0,
      'name': name,
      'description': 'Friendly place created by Trakkar',
      'area': area,
      'calendarId': 0,
      'attributes': <String, dynamic>{
        'trakkarNamedPlace': true,
        'trakkarSchemaVersion': 2,
      },
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'boundary': boundary
        .map((point) => <double>[point.latitude, point.longitude])
        .toList(growable: false),
    'serverBacked': serverBacked,
  };

  String encode() => jsonEncode(toJson());

  static LatLng _centerOf(List<LatLng> points) {
    final latitude = points.fold<double>(
      0,
      (total, point) => total + point.latitude,
    );
    final longitude = points.fold<double>(
      0,
      (total, point) => total + point.longitude,
    );
    return LatLng(latitude / points.length, longitude / points.length);
  }
}
