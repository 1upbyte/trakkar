import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:traccar_client_sdk/traccar_client_sdk.dart';

import 'local_diagnostics.dart';

class TrackingHealth {
  const TrackingHealth({
    required this.checked,
    required this.locationAlways,
    this.locationPrecise = true,
    required this.activityRecognitionOkay,
    required this.batteryOptimizationOkay,
    required this.batteryOptimizationRelevant,
  });

  const TrackingHealth.unchecked()
    : checked = false,
      locationAlways = true,
      locationPrecise = true,
      activityRecognitionOkay = true,
      batteryOptimizationOkay = true,
      batteryOptimizationRelevant = false;

  factory TrackingHealth.fromMap(Map<Object?, Object?> map) {
    return TrackingHealth(
      checked: true,
      locationAlways: map['locationAlways'] == true,
      // Android and older bridges omit this iOS permission field.
      locationPrecise: map['locationPrecise'] != false,
      // Older iOS bridges do not return this Android-only field.
      activityRecognitionOkay: map['activityRecognitionOkay'] != false,
      batteryOptimizationOkay: map['batteryOptimizationOkay'] == true,
      batteryOptimizationRelevant: map['batteryOptimizationRelevant'] == true,
    );
  }

  final bool checked;
  final bool locationAlways;
  final bool locationPrecise;
  final bool activityRecognitionOkay;
  final bool batteryOptimizationOkay;
  final bool batteryOptimizationRelevant;

  bool get needsLocation => checked && !locationAlways;
  bool get needsPreciseLocation => checked && !locationPrecise;
  bool get needsActivity => checked && !activityRecognitionOkay;
  bool get needsBattery =>
      checked && batteryOptimizationRelevant && !batteryOptimizationOkay;
  bool get hasWarning =>
      needsLocation || needsPreciseLocation || needsActivity || needsBattery;
}

class TrackerService {
  TrackerService({TraccarClientSdk? sdk}) : _sdk = sdk ?? TraccarClientSdk();

  final TraccarClientSdk _sdk;

  static const _platform = MethodChannel(
    'com.oneupbyte.trakkar/tracking-support',
  );

  Future<void> configure({
    required Uri serverUrl,
    required String deviceId,
  }) async {
    LocalDiagnostics.record(DiagnosticEvent.trackerConfiguring);
    final connection = {
      'serverUrl': serverUrl.toString(),
      'deviceId': deviceId,
    };
    if (defaultTargetPlatform == TargetPlatform.android) {
      // The native controller initializes or updates the SDK once, after any
      // pending foreground-service startup. This is required for core tracking.
      await const MethodChannel('trakkar/live_tracking')
          .invokeMethod<void>('configure', connection);
      return;
    }
    final config = Config(
      serverUrl: serverUrl.toString(),
      deviceId: deviceId,
      location: const LocationConfig(
        accuracy: Accuracy.medium,
        // iOS providers ignore the SDK's effective interval. Its upload filter
        // uses the original config and ORs time with distance, so zero accepts
        // every fix. An unreachable distance leaves only the time trigger.
        distanceMeters: 0x7fffffff,
        intervalSeconds: 600,
        stopDetection: true,
        stopTimeoutSeconds: 120,
        stationaryRadiusMeters: 100,
      ),
      buffer: true,
      notification: const NotificationConfig(
        text: 'Trakkar is sharing your location',
      ),
    );
    await _sdk.init(config);
    await _sdk.setConfig(config);
    await _invokeLive('configure', connection);
  }

  Future<void> start() async {
    LocalDiagnostics.record(DiagnosticEvent.trackerStarting);
    await _sdk.start();
    await _invokeLive('setEnabled', {'enabled': true});

    // The Traccar SDK requests Always authorization from an undetermined
    // state. If the user previously chose While Using, SDK 1.0.10 accepts
    // that status without requesting the one permitted upgrade to Always.
    // This bridge only requests authorization; Traccar SDK remains the sole
    // owner of location collection and background tracking.
    if (Platform.isIOS) {
      await _platform.invokeMethod<void>('requestAlwaysIfNeeded');
    }
  }

  Future<TrackingHealth> trackingHealth() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const TrackingHealth(
        checked: true,
        locationAlways: true,
        activityRecognitionOkay: true,
        batteryOptimizationOkay: true,
        batteryOptimizationRelevant: false,
      );
    }
    final result = await _platform.invokeMapMethod<Object?, Object?>(
      'getTrackingHealth',
    );
    return TrackingHealth.fromMap(result ?? const <Object?, Object?>{});
  }

  Future<void> openLocationSettings() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _platform.invokeMethod<void>('openLocationSettings');
    }
  }

  Future<void> openBatterySettings() async {
    if (Platform.isAndroid) {
      await _platform.invokeMethod<void>('openBatterySettings');
    }
  }

  Future<void> stop() async {
    LocalDiagnostics.record(DiagnosticEvent.trackerStopping);
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Disabling the extension is part of stopping location sharing. Report
        // failure so callers cannot claim it stopped while pushes remain enabled.
        await const MethodChannel('trakkar/live_tracking')
            .invokeMethod<void>('setEnabled', {'enabled': false});
      } else {
        await _invokeLive('setEnabled', {'enabled': false});
      }
    } finally {
      await _sdk.stop();
    }
  }

  Future<void> _invokeLive(String method, Map<String, Object> arguments) async {
    try {
      await const MethodChannel('trakkar/live_tracking')
          .invokeMethod<void>(method, arguments);
    } on PlatformException {
      debugPrint('Live tracking native setup unavailable.');
    } on MissingPluginException {
      debugPrint('Live tracking native integration unavailable.');
    }
  }

  Future<bool> isTracking() => _sdk.isTracking();

  Future<bool> sendNow() => _sdk.requestPosition();

  Future<List<LogEntry>> logs() => _sdk.getLogs();

  Future<void> clearLogs() => _sdk.clearLogs();
}
