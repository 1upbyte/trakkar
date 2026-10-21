import 'dart:convert';

class ProvisioningConfig {
  const ProvisioningConfig({
    required this.clientUrl,
    required this.managerUrl,
    required this.managerUsername,
    required this.managerPassword,
    this.liveTrackingUrl,
  });

  final Uri clientUrl;
  final Uri managerUrl;
  final Uri? liveTrackingUrl;
  final String managerUsername;
  final String managerPassword;

  factory ProvisioningConfig.fromFields({
    required String clientUrl,
    required String managerUrl,
    required String managerUsername,
    required String managerPassword,
    String liveTrackingUrl = '',
  }) {
    final username = managerUsername.trim();
    if (username.isEmpty) {
      throw const FormatException('Enter the manager username.');
    }
    if (managerPassword.isEmpty) {
      throw const FormatException('Enter the manager password.');
    }
    return ProvisioningConfig(
      clientUrl: _parseHttpUrl(clientUrl, 'client'),
      managerUrl: _parseHttpUrl(managerUrl, 'manager'),
      liveTrackingUrl: _parseLiveTrackingUrl(liveTrackingUrl),
      managerUsername: username,
      managerPassword: managerPassword,
    );
  }

  static ProvisioningConfig fromQr(String encoded) {
    final compact = encoded.trim().replaceAll(RegExp(r'\s'), '');
    if (compact.isEmpty) {
      throw const FormatException('The QR code is empty.');
    }

    late final String decoded;
    try {
      decoded = utf8.decode(base64Decode(base64.normalize(compact)));
    } on Object {
      throw const FormatException('The QR code is not valid base64.');
    }

    final parts = decoded.split(';');
    final versioned = parts.first == 'v2';
    if (parts.length < (versioned ? 6 : 4)) {
      throw const FormatException('The QR code is missing connection fields.');
    }

    return ProvisioningConfig.fromFields(
      clientUrl: parts[versioned ? 1 : 0],
      managerUrl: parts[versioned ? 2 : 1],
      liveTrackingUrl: versioned ? parts[3] : '',
      managerUsername: parts[versioned ? 4 : 2],
      managerPassword: parts.sublist(versioned ? 5 : 3).join(';'),
    );
  }

  static ProvisioningConfig fromSetupLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'trakkar' ||
        uri.host != 'setup' ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['data']?.length != 1) {
      throw const FormatException('This is not a valid Trakkar setup link.');
    }
    return fromQr(uri.queryParameters['data']!);
  }

  Uri toSetupLink() {
    final payload = [
      'v2',
      clientUrl.toString(),
      managerUrl.toString(),
      liveTrackingUrl?.toString() ?? '',
      managerUsername,
      managerPassword,
    ].join(';');
    return Uri(
      scheme: 'trakkar',
      host: 'setup',
      queryParameters: {'data': base64UrlEncode(utf8.encode(payload))},
    );
  }

  static Uri? _parseLiveTrackingUrl(String value) {
    if (value.trim().isEmpty) return null;
    final uri = _parseHttpUrl(value, 'live tracking');
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Enter a live tracking HTTPS URL without credentials, query, or fragment.',
      );
    }
    return uri;
  }

  static Uri _parseHttpUrl(String value, String label) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw FormatException(
        'Enter a valid $label URL starting with http:// or https://.',
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  Map<String, String> toStorage() => <String, String>{
    'clientUrl': clientUrl.toString(),
    'managerUrl': managerUrl.toString(),
    'liveTrackingUrl': liveTrackingUrl?.toString() ?? '',
    'managerUsername': managerUsername,
    'managerPassword': managerPassword,
  };

  static ProvisioningConfig fromStorage(Map<String, String> values) {
    return ProvisioningConfig(
      clientUrl: _parseHttpUrl(values['clientUrl'] ?? '', 'client'),
      managerUrl: _parseHttpUrl(values['managerUrl'] ?? '', 'manager'),
      liveTrackingUrl: _parseLiveTrackingUrl(values['liveTrackingUrl'] ?? ''),
      managerUsername: values['managerUsername'] ?? '',
      managerPassword: values['managerPassword'] ?? '',
    );
  }
}
