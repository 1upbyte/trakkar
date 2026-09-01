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
}
