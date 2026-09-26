import 'package:latlong2/latlong.dart';

class PersonMapEntry {
  const PersonMapEntry({
    required this.personId,
    required this.deviceId,
    required this.displayName,
    required this.imageRef,
    required this.position,
    required this.batteryLevel,
    required this.fixTime,
  });

  final String personId;
  final int deviceId;
  final String displayName;
  final String? imageRef;
  final LatLng? position;
  final double? batteryLevel;
  final DateTime? fixTime;

  String get initials {
    final words = displayName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words
        .take(2)
        .map((word) => word.substring(0, 1))
        .join()
        .toUpperCase();
  }

  factory PersonMapEntry.fromTraccar({
    required Map<String, dynamic> device,
    Map<String, dynamic>? position,
  }) {
    final attrs = _map(device['attributes']);
    final positionAttrs = _map(position?['attributes']);
    final battery = _number(
      positionAttrs['batteryLevel'] ??
          positionAttrs['battery'] ??
          attrs['batteryLevel'] ??
          attrs['battery'],
    );
    final latitude = _number(position?['latitude']);
    final longitude = _number(position?['longitude']);
    final hasPosition =
        latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    return PersonMapEntry(
      personId: '${device['id'] ?? ''}',
      deviceId: (device['id'] as num?)?.toInt() ?? 0,
      displayName: (device['name'] as String?)?.trim().isNotEmpty == true
          ? (device['name'] as String).trim()
          : 'Unknown person',
      imageRef: _imageReference(device, attrs),
      position: hasPosition ? LatLng(latitude, longitude) : null,
      batteryLevel: battery != null && battery >= 0 && battery <= 100
          ? battery
          : null,
      fixTime: DateTime.tryParse(
        (position?['fixTime'] ?? position?['deviceTime'] ?? '').toString(),
      ),
    );
  }
}

String? _imageReference(
  Map<String, dynamic> device,
  Map<String, dynamic> attrs,
) {
  final image = attrs['deviceImage'] ?? attrs['image'] ?? attrs['photo'];
  if (image is! String || image.isEmpty) return null;
  if (attrs['deviceImage'] == image && device['uniqueId'] is String) {
    return 'traccar-media:${device['uniqueId']}/$image';
  }
  return image;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

double? _number(Object? value) => value is num ? value.toDouble() : null;
