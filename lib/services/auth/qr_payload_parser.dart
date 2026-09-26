import 'dart:convert';

import '../../models/login_details.dart';

class InvalidQrPayload implements Exception {
  const InvalidQrPayload();
}

class QrPayloadParser {
  const QrPayloadParser();

  LoginDetailsDraft parse(String raw) {
    final payload = raw.trim();
    if (payload.isEmpty || RegExp(r'\s').hasMatch(payload)) {
      throw const InvalidQrPayload();
    }

    try {
      final bytes = base64.decode(payload);
      if (base64.encode(bytes) != payload) throw const InvalidQrPayload();
      final decoded = utf8.decode(bytes, allowMalformed: false);
      if (decoded.split(';').length != 4) throw const InvalidQrPayload();
      final fields = decoded.split(';');
      if (fields.any((field) => field.isEmpty)) throw const InvalidQrPayload();
      return LoginDetailsDraft(
        username: fields[0],
        password: fields[1],
        clientUrl: fields[2],
        managerUrl: fields[3],
        source: LoginSource.qr,
      );
    } on InvalidQrPayload {
      rethrow;
    } on FormatException {
      throw const InvalidQrPayload();
    }
  }
}
