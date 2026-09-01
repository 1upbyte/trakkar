import 'dart:convert';

class NamedPlace {
  const NamedPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150,
    this.serverBacked = false,
  });

  factory NamedPlace.fromJson(Map<String, dynamic> json) {
    return NamedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 150,
      serverBacked: json['serverBacked'] as bool? ?? false,
    );
  }

  factory NamedPlace.fromGeofence(Map<String, dynamic> json) {
    final area = json['area'] as String? ?? '';
    final match = RegExp(
      r'^CIRCLE\s*\(\s*([-+0-9.eE]+)\s+([-+0-9.eE]+)\s*,\s*([-+0-9.eE]+)\s*\)$',
      caseSensitive: false,
    ).firstMatch(area);
    if (match == null) {
      throw const FormatException('Named place must be a circular geofence.');
    }
    return NamedPlace(
      id: (json['id'] as num).toInt().toString(),
      name: json['name'] as String? ?? 'Unnamed place',
      latitude: double.parse(match.group(1)!),
      longitude: double.parse(match.group(2)!),
      radiusMeters: double.parse(match.group(3)!),
      serverBacked: true,
    );
  }

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool serverBacked;

  int? get serverId => int.tryParse(id);

  Map<String, dynamic> toGeofencePayload() => <String, dynamic>{
    'id': 0,
    'name': name,
    'description': 'Friendly place created by Trakkar',
    'area': 'CIRCLE ($latitude $longitude, $radiusMeters)',
    'calendarId': 0,
    'attributes': <String, dynamic>{
      'trakkarNamedPlace': true,
      'trakkarSchemaVersion': 1,
    },
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'serverBacked': serverBacked,
  };

  String encode() => jsonEncode(toJson());
}
