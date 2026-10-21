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
      expect(config.liveTrackingUrl, isNull);
    });

    test('parses v2 live tracking URL and preserves password separators', () {
      final config = ProvisioningConfig.fromQr(
        base64Encode(
          utf8.encode(
            'v2;https://client.test;https://manager.test;'
            'https://live.test/api/;admin;a;b;c',
          ),
        ),
      );

      expect(config.liveTrackingUrl, Uri.parse('https://live.test/api'));
      expect(config.managerUsername, 'admin');
      expect(config.managerPassword, 'a;b;c');
      expect(
        ProvisioningConfig.fromStorage(config.toStorage()).liveTrackingUrl,
        config.liveTrackingUrl,
      );
    });

    test('allows an empty v2 live tracking field', () {
      final config = ProvisioningConfig.fromQr(
        base64Encode(
          utf8.encode(
            'v2;https://client.test;https://manager.test;;admin;secret',
          ),
        ),
      );
      expect(config.liveTrackingUrl, isNull);
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

  group('setup links', () {
    test('round trips credentials, live endpoint, and special characters', () {
      final config = ProvisioningConfig.fromFields(
        clientUrl: 'https://client.test',
        managerUrl: 'https://manager.test',
        liveTrackingUrl: 'https://live.test',
        managerUsername: 'friend@example.com',
        managerPassword: 'secret;+&?# café',
      );
      final link = config.toSetupLink();
      expect(link.scheme, 'trakkar');
      expect(link.host, 'setup');
      expect(
        ProvisioningConfig.fromSetupLink(link.toString()).toStorage(),
        config.toStorage(),
      );
    });

    test('rejects malformed and unrelated links', () {
      for (final link in [
        'https://setup?data=abc',
        'trakkar://other?data=abc',
        'trakkar://setup',
        'trakkar://setup?data=not-base64',
        'trakkar://setup/path?data=abc',
        'trakkar://setup?data=abc&data=def',
        'trakkar://setup?data=abc&extra=value',
      ]) {
        expect(
          () => ProvisioningConfig.fromSetupLink(link),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  group('ProvisioningConfig.fromFields', () {
    test('validates and normalizes manually entered fields', () {
      final config = ProvisioningConfig.fromFields(
        clientUrl: ' https://client.test/ ',
        managerUrl: 'https://manager.test/api/',
        liveTrackingUrl: ' https://live.test/ ',
        managerUsername: ' manager ',
        managerPassword: 'secret',
      );

      expect(config.clientUrl.toString(), 'https://client.test');
      expect(config.managerUrl.toString(), 'https://manager.test/api');
      expect(config.managerUsername, 'manager');
      expect(config.liveTrackingUrl, Uri.parse('https://live.test'));
    });

    test('rejects unsafe live tracking endpoints', () {
      for (final endpoint in [
        'http://live.test',
        'https://user:pass@live.test',
        'https://live.test?key=value',
        'https://live.test#fragment',
        'invalid',
      ]) {
        expect(
          () => ProvisioningConfig.fromFields(
            clientUrl: 'https://client.test',
            managerUrl: 'https://manager.test',
            managerUsername: 'admin',
            managerPassword: 'secret',
            liveTrackingUrl: endpoint,
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('loads legacy stored settings without live tracking', () {
      final config = ProvisioningConfig.fromStorage({
        'clientUrl': 'https://client.test',
        'managerUrl': 'https://manager.test',
        'managerUsername': 'admin',
        'managerPassword': 'secret',
      });
      expect(config.liveTrackingUrl, isNull);
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
