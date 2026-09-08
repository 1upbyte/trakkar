class TraccarPosition {
  const TraccarPosition({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.valid,
    this.fixTime,
    this.speed = 0,
    this.course = 0,
    this.accuracy = 0,
    this.address,
    this.attributes = const <String, dynamic>{},
  });

  factory TraccarPosition.fromJson(Map<String, dynamic> json) {
    return TraccarPosition(
      id: (json['id'] as num).toInt(),
      deviceId: (json['deviceId'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      valid: json['valid'] as bool? ?? true,
      fixTime: DateTime.tryParse(json['fixTime'] as String? ?? ''),
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      course: (json['course'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      attributes: Map<String, dynamic>.from(
        json['attributes'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  final int id;
  final int deviceId;
  final double latitude;
  final double longitude;
  final bool valid;
  final DateTime? fixTime;
  final double speed;
  final double course;
  final double accuracy;
  final String? address;
  final Map<String, dynamic> attributes;

  double get speedMph => speed <= 0 ? 0 : speed * 1.150779448;

  bool get isMoving {
    final value = attributes['motion'];
    final serverSaysStopped = switch (value) {
      bool value => !value,
      num value => value == 0,
      String value => value.toLowerCase() == 'false',
      _ => false,
    };
    if (serverSaysStopped) return false;

    // Traccar's motion state can remain true briefly after a person stops.
    // Require meaningful speed as well so a 0 mph fix clears the UI badge.
    return speedMph >= 1;
  }
}

/// Preserve the last usable fix when a device loses GPS or responses arrive late.
Map<int, TraccarPosition> mergeLastKnownPositions(
  Map<int, TraccarPosition> previous,
  Iterable<TraccarPosition> incoming,
) {
  final result = Map<int, TraccarPosition>.from(previous);
  for (final position in incoming) {
    final old = result[position.deviceId];
    if (old != null) {
      if (old.valid && !position.valid) continue;
      if (old.fixTime != null &&
          position.fixTime != null &&
          position.fixTime!.isBefore(old.fixTime!)) {
        continue;
      }
    }
    result[position.deviceId] = position;
  }
  return result;
}
