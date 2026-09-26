class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    this.profileImageRef,
  });

  final int userId;
  final String displayName;
  final String? profileImageRef;

  UserProfile copyWith({String? displayName, String? profileImageRef}) =>
      UserProfile(
        userId: userId,
        displayName: displayName ?? this.displayName,
        profileImageRef: profileImageRef ?? this.profileImageRef,
      );

  static UserProfile? fromTraccar(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final name = (json['name'] as String?)?.trim();
    if (id == null || name == null || name.isEmpty) return null;
    return UserProfile(userId: id, displayName: name);
  }
}
