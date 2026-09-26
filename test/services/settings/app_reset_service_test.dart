import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trakkar/models/login_details.dart';
import 'package:trakkar/services/auth/secure_session_store.dart';
import 'package:trakkar/services/settings/app_reset_service.dart';
import 'package:trakkar/services/settings/preferences_repository.dart';
import 'package:trakkar/services/settings/sdk_configuration_reset_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'clears local setup in order while preserving unrelated preference data',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings.themeMode': 'dark',
        'map.satelliteThresholdZoom': 16.0,
        'other.feature': 'preserve',
      });
      final events = <String>[];
      final store = _SessionStore(events);
      final tracker = _Tracking(events);
      await AppResetService(
        sessionStore: store,
        preferences: PreferencesRepository(),
        tracking: tracker,
      ).reset();
      expect(events, ['stop', 'clear-sdk', 'clear-session']);
      expect(tracker.positions, [1, 2]);
      expect(store.cleared, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('settings.themeMode'), isNull);
      expect(preferences.getDouble('map.satelliteThresholdZoom'), 19);
      expect(preferences.getString('other.feature'), 'preserve');
    },
  );

  test('retains session and preferences when SDK config clear fails', () async {
    SharedPreferences.setMockInitialValues({
      'settings.themeMode': 'dark',
      'map.satelliteThresholdZoom': 16.0,
    });
    final events = <String>[];
    final store = _SessionStore(events);
    final tracker = _Tracking(events, failClear: true);
    await expectLater(
      AppResetService(
        sessionStore: store,
        preferences: PreferencesRepository(),
        tracking: tracker,
      ).reset(),
      throwsA(isA<AppResetFailure>()),
    );
    expect(events, ['stop', 'clear-sdk', 'resume']);
    expect(store.cleared, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('settings.themeMode'), 'dark');
    expect(preferences.getDouble('map.satelliteThresholdZoom'), 16);
  });
}

class _SessionStore implements SessionStore {
  _SessionStore(this.events);
  final List<String> events;
  bool cleared = false;

  @override
  Future<void> clear() async {
    events.add('clear-session');
    cleared = true;
  }

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> save(LoginDetailsDraft details, String cookie) async {}
}

class _Tracking implements TrackingResetService {
  _Tracking(this.events, {this.failClear = false});
  final List<String> events;
  final bool failClear;
  final positions = [1, 2];

  @override
  Future<void> clearConfiguration() async {
    events.add('clear-sdk');
    if (failClear) throw const PendingPositionsPreventReset();
  }

  @override
  Future<void> resumeAfterFailedReset() async => events.add('resume');

  @override
  Future<void> stop() async => events.add('stop');
}
