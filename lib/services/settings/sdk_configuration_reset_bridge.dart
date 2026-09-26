import 'package:flutter/services.dart';

abstract interface class TrackingResetService {
  Future<void> stop();
  Future<void> resumeAfterFailedReset();
  Future<void> clearConfiguration();
}

abstract interface class SdkConfigurationResetBridge {
  Future<void> clearConfiguration();
}

class MethodChannelSdkConfigurationResetBridge
    implements SdkConfigurationResetBridge {
  // Keep the channel injectable for tests without exposing it as public state.
  const MethodChannelSdkConfigurationResetBridge({
    MethodChannel channel = const MethodChannel('trakkar/settings_reset'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> clearConfiguration() async {
    try {
      await _channel.invokeMethod<void>('clearSdkConnectionConfig');
    } on PlatformException catch (error) {
      if (error.code == 'sdk_reset_queue_pending') {
        throw const PendingPositionsPreventReset();
      }
      rethrow;
    }
  }
}

class PendingPositionsPreventReset implements Exception {
  const PendingPositionsPreventReset();
}
