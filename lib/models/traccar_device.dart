class TraccarDevice {
  const TraccarDevice({
    required this.id,
    required this.name,
    required this.uniqueId,
    required this.status,
    required this.raw,
    this.positionId,
    this.lastUpdate,
  });

  factory TraccarDevice.fromJson(Map<String, dynamic> json) {
    return TraccarDevice(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Unnamed device',
      uniqueId: json['uniqueId'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      positionId: (json['positionId'] as num?)?.toInt(),
      lastUpdate: DateTime.tryParse(json['lastUpdate'] as String? ?? ''),
      raw: Map<String, dynamic>.from(json),
    );
  }

  final int id;
  final String name;
  final String uniqueId;
  final String status;
  final int? positionId;
  final DateTime? lastUpdate;
  final Map<String, dynamic> raw;

  Map<String, dynamic> get attributes => Map<String, dynamic>.from(
    raw['attributes'] as Map? ?? const <String, dynamic>{},
  );

  /// Marker attribute name written while a phone has the map open.
  static const watchUntilAttribute = 'trakkarWatchUntil';

  /// Epoch time until which this device's owner is actively watching the
  /// map, or null when the attribute is absent or unreadable.
  DateTime? get watchUntil {
    final value = attributes[watchUntilAttribute];
    final millis = switch (value) {
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  bool isWatchingAt(DateTime now) {
    final until = watchUntil;
    return until != null && until.isAfter(now);
  }

  String? get imageName {
    final value = attributes['deviceImage'] as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  TraccarDevice copyWith({String? name, String? status, DateTime? lastUpdate}) {
    return TraccarDevice(
      id: id,
      name: name ?? this.name,
      uniqueId: uniqueId,
      status: status ?? this.status,
      positionId: positionId,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      raw: raw,
    );
  }

  Map<String, dynamic> updatePayload({required String displayName}) {
    return <String, dynamic>{
      ...raw,
      'id': id,
      'name': displayName,
      'uniqueId': uniqueId,
    };
  }

  Map<String, dynamic> updateAttributesPayload(
    Map<String, dynamic> updatedAttributes,
  ) {
    return <String, dynamic>{
      ...raw,
      'id': id,
      'name': name,
      'uniqueId': uniqueId,
      'attributes': updatedAttributes,
    };
  }
}
