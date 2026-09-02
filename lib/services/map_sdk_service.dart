import 'dart:io';

import 'package:flutter/services.dart';

/// Hands runtime map SDK credentials to the native Google Maps SDKs.
///
/// Google's mobile SDKs normally read their key from the Android manifest or
/// from `GMSServices.provideAPIKey` in the iOS app delegate. Trakkar keeps the
/// key on the Traccar server instead, so the key is delivered through this
/// channel before the first map view is created.
class MapSdkService {
  MapSdkService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.oneupbyte.trakkar/map-sdk';

  final MethodChannel _channel;
  String? _appliedGoogleKey;

  String? get appliedGoogleKey => _appliedGoogleKey;

  /// Applies [key] to the native Google Maps SDK. Returns true when the
  /// platform accepted the key. Repeated calls with the same key are no-ops.
  Future<bool> applyGoogleMapsKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) return false;
    if (_appliedGoogleKey == clean) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final accepted =
        await _channel.invokeMethod<bool>('setGoogleMapsApiKey', <String, Object>{
          'key': clean,
        }) ??
        false;
    if (accepted) _appliedGoogleKey = clean;
    return accepted;
  }
}
