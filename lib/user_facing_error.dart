import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'services/traccar_api.dart';

String userFacingError(Object error) {
  if (error is TraccarApiException) return error.message;
  if (error is FormatException) return error.message.toString();
  if (error is TimeoutException) {
    return 'The server took too long to respond. Check the URL and connection.';
  }
  if (error is SocketException || error is http.ClientException) {
    return 'Could not reach the server. Check the URL and your connection.';
  }
  if (error is PlatformException) {
    final message = (error.message ?? '').toLowerCase();
    if (message.contains('permission') || message.contains('denied')) {
      return 'Location permission was not granted. You can enable it in system settings.';
    }
    return 'The phone could not complete that operation. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}
