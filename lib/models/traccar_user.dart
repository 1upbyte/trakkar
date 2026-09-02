class TraccarUser {
  const TraccarUser({
    required this.id,
    required this.name,
    required this.email,
    required this.raw,
  });

  factory TraccarUser.fromJson(Map<String, dynamic> json) {
    return TraccarUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      raw: Map<String, dynamic>.from(json),
    );
  }

  final int id;
  final String name;
  final String email;
  final Map<String, dynamic> raw;

  Map<String, dynamic> get attributes => Map<String, dynamic>.from(
    raw['attributes'] as Map? ?? const <String, dynamic>{},
  );

  /// Full user payload with replaced attributes. Traccar's `PUT /api/users`
  /// replaces the whole record, so every other field is preserved verbatim.
  /// The password is never included; the session response omits it and the
  /// server keeps the stored hash when it is absent.
  Map<String, dynamic> updateAttributesPayload(
    Map<String, dynamic> updatedAttributes,
  ) {
    final payload = <String, dynamic>{...raw, 'attributes': updatedAttributes};
    payload.remove('password');
    return payload;
  }
}
