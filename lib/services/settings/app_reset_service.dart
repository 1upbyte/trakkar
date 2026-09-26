import '../../models/reset_request.dart';
import '../auth/secure_session_store.dart';
import 'preferences_repository.dart';
import 'sdk_configuration_reset_bridge.dart';

class AppResetFailure implements Exception {
  const AppResetFailure({this.pendingPositions = false});

  final bool pendingPositions;

  String get message => pendingPositions
      ? 'Let pending positions sync with this server, then try Reset App again.'
      : 'Reset could not finish. Your account is still available to retry.';
}

class AppResetService {
  // Keep public injection names while keeping service fields private.
  const AppResetService({
    required SessionStore sessionStore,
    required PreferencesRepository preferences,
    required TrackingResetService tracking,
  }) : _sessionStore = sessionStore,
       _preferences = preferences,
       _tracking = tracking;

  final SessionStore _sessionStore;
  final PreferencesRepository _preferences;
  final TrackingResetService _tracking;

  Future<void> reset({ValueChanged<ResetStatus>? onStatus}) async {
    try {
      onStatus?.call(ResetStatus.stoppingTracking);
      await _tracking.stop();
      await _tracking.clearConfiguration();
      onStatus?.call(ResetStatus.clearingLocalConfig);
      await _preferences.reset();
      await _sessionStore.clear();
      onStatus?.call(ResetStatus.complete);
    } on Object catch (error) {
      try {
        await _tracking.resumeAfterFailedReset();
      } on Object {
        // Preserve the original reset error if tracking cannot be restarted.
      }
      onStatus?.call(ResetStatus.failed);
      throw AppResetFailure(
        pendingPositions: error is PendingPositionsPreventReset,
      );
    }
  }
}

typedef ValueChanged<T> = void Function(T value);
