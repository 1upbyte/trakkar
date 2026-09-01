import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/provisioning_config.dart';

void main() {
  group('ProvisioningConfig.fromQr', () {
    test('parses the four-field base64 payload', () {
      final encoded = base64Encode(
        utf8.encode(
          'https://client.example.com;https://manager.example.com;'
          'manager@example.com;secret',
        ),
      );

      final config = ProvisioningConfig.fromQr(encoded);

      expect(config.clientUrl, Uri.parse('https://client.example.com'));
      expect(config.managerUrl, Uri.parse('https://manager.example.com'));
      expect(config.managerUsername, 'manager@example.com');
      expect(config.managerPassword, 'secret');
    });

    test('keeps semicolons inside the password', () {
      final encoded = base64Encode(
        utf8.encode('https://client.test;https://manager.test;admin;a;b;c'),
      );

      expect(ProvisioningConfig.fromQr(encoded).managerPassword, 'a;b;c');
    });

    test('accepts URL-safe base64 without padding', () {
      final encoded = base64UrlEncode(
        utf8.encode('https://client.test;https://manager.test;admin;pass'),
      ).replaceAll('=', '');

      expect(ProvisioningConfig.fromQr(encoded).managerUsername, 'admin');
    });

    test('rejects invalid URLs', () {
      final encoded = base64Encode(
        utf8.encode('not-a-url;https://manager.test;admin;pass'),
      );

      expect(
        () => ProvisioningConfig.fromQr(encoded),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ProvisioningConfig.fromFields', () {
    test('validates and normalizes manually entered fields', () {
      final config = ProvisioningConfig.fromFields(
        clientUrl: ' https://client.test/ ',
        managerUrl: 'https://manager.test/api/',
        managerUsername: ' manager ',
        managerPassword: 'secret',
      );

      expect(config.clientUrl.toString(), 'https://client.test');
      expect(config.managerUrl.toString(), 'https://manager.test/api');
      expect(config.managerUsername, 'manager');
    });

    test('requires both manager credentials', () {
      expect(
        () => ProvisioningConfig.fromFields(
          clientUrl: 'https://client.test',
          managerUrl: 'https://manager.test',
          managerUsername: '',
          managerPassword: '',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
