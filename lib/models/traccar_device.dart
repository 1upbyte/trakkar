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
}
