class ServerDetails {
  const ServerDetails({
    required this.clientUrl,
    required this.managerUrl,
    required this.accountName,
  });

  final String? clientUrl;
  final String? managerUrl;
  final String? accountName;

  factory ServerDetails.redacted({
    required String? clientUrl,
    required String? managerUrl,
    required String? accountName,
  }) => ServerDetails(
    clientUrl: _safeAddress(clientUrl),
    managerUrl: _safeAddress(managerUrl),
    accountName: _nonEmpty(accountName),
  );

  static String? _safeAddress(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    ).toString();
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
