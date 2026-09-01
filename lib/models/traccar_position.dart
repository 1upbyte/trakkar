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
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    // Some protocols omit Traccar's standardized motion attribute. Avoid
    // treating normal GPS drift as movement in that fallback case.
    return speedMph >= 1;
  }
}
