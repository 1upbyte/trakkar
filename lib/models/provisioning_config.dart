import 'dart:convert';

class ProvisioningConfig {
  const ProvisioningConfig({
    required this.clientUrl,
    required this.managerUrl,
    required this.managerUsername,
    required this.managerPassword,
  });

  final Uri clientUrl;
  final Uri managerUrl;
  final String managerUsername;
  final String managerPassword;

  factory ProvisioningConfig.fromFields({
    required String clientUrl,
    required String managerUrl,
    required String managerUsername,
    required String managerPassword,
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
    if (parts.length < 4) {
      throw const FormatException(
        'The QR code must contain client URL, manager URL, username, and password.',
      );
    }

    return ProvisioningConfig.fromFields(
      clientUrl: parts[0],
      managerUrl: parts[1],
      managerUsername: parts[2],
      managerPassword: parts.sublist(3).join(';'),
    );
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
    'managerUsername': managerUsername,
    'managerPassword': managerPassword,
  };

  static ProvisioningConfig fromStorage(Map<String, String> values) {
    return ProvisioningConfig(
      clientUrl: _parseHttpUrl(values['clientUrl'] ?? '', 'client'),
      managerUrl: _parseHttpUrl(values['managerUrl'] ?? '', 'manager'),
      managerUsername: values['managerUsername'] ?? '',
      managerPassword: values['managerPassword'] ?? '',
    );
  }
}
