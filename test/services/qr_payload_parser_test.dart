import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/services/auth/qr_payload_parser.dart';

void main() {
  const parser = QrPayloadParser();

  String encoded(String value) => base64.encode(utf8.encode(value));

  test('decodes the four fields in contract order, including UTF-8', () {
    final details = parser.parse(encoded('josé;páss;not a url;://manager'));

    expect(details.username, 'josé');
    expect(details.password, 'páss');
    expect(details.clientUrl, 'not a url');
    expect(details.managerUrl, '://manager');
  });

  test('trims only surrounding scanner whitespace', () {
    expect(parser.parse('  ${encoded('u;p;c;m')}\n').username, 'u');
    final value = encoded('u;p;c;m');
    expect(
      () => parser.parse('${value.substring(0, 2)} ${value.substring(2)}'),
      throwsA(isA<InvalidQrPayload>()),
    );
  });

  test('rejects malformed base64 and invalid UTF-8', () {
    expect(() => parser.parse('%%%'), throwsA(isA<InvalidQrPayload>()));
    expect(
      () => parser.parse(base64.encode([0xff, 0xff])),
      throwsA(isA<InvalidQrPayload>()),
    );
  });

  test('rejects any payload that is not exactly four non-empty fields', () {
    for (final value in [
      'u;p;c',
      'u;p;c;m;extra',
      ';p;c;m',
      'u;;c;m',
      'u;p;;m',
      'u;p;c;',
    ]) {
      expect(
        () => parser.parse(encoded(value)),
        throwsA(isA<InvalidQrPayload>()),
        reason: value,
      );
    }
  });
}
