enum LoginSource { qr, manual }

class LoginDetailsDraft {
  const LoginDetailsDraft({
    required this.username,
    required this.password,
    required this.clientUrl,
    required this.managerUrl,
    required this.source,
  });

  final String username;
  final String password;
  final String clientUrl;
  final String managerUrl;
  final LoginSource source;

  bool get hasRequiredValues =>
      username.isNotEmpty &&
      password.isNotEmpty &&
      clientUrl.isNotEmpty &&
      managerUrl.isNotEmpty;

  LoginDetailsDraft copyWith({
    String? username,
    String? password,
    String? clientUrl,
    String? managerUrl,
  }) => LoginDetailsDraft(
    username: username ?? this.username,
    password: password ?? this.password,
    clientUrl: clientUrl ?? this.clientUrl,
    managerUrl: managerUrl ?? this.managerUrl,
    source: source,
  );
}
