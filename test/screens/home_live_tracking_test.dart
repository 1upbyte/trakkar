import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/screens/home_screen.dart';
import 'package:trakkar/services/tracker_service.dart';

class _VisibilityState extends AppState {
  final foreground = <bool>[];
  var permissionSettingsOpened = 0;

  void setHealth(TrackingHealth health) {
    trackingHealth = health;
    notifyListeners();
  }

  @override
  Future<void> openLocationSettings() async {
    permissionSettingsOpened++;
  }

  @override
  void setAppForeground(bool visible) {
    foreground.add(visible);
  }

  @override
  Future<void> refreshTrackingHealth() async {}
}

void main() {
  testWidgets(
    'reduced precision offers settings and clears after restoration',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = _VisibilityState();
      addTearDown(state.dispose);
      state.setHealth(
        TrackingHealth.fromMap(const {
          'locationAlways': true,
          'locationPrecise': false,
          'batteryOptimizationOkay': true,
        }),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      expect(find.textContaining('enable Precise Location'), findsOneWidget);
      await tester.tap(find.text('Permission settings'));
      await tester.pump();
      expect(state.permissionSettingsOpened, 1);

      state.setHealth(
        TrackingHealth.fromMap(const {
          'locationAlways': true,
          'locationPrecise': true,
          'batteryOptimizationOkay': true,
        }),
      );
      await tester.pump();
      expect(find.textContaining('enable Precise Location'), findsNothing);
      expect(find.text('Permission settings'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'background launches stay inactive and all foreground tabs keep viewing',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = _VisibilityState();
      addTearDown(state.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      expect(state.foreground.last, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(state.foreground.last, isTrue);
      await tester.tap(find.text('People').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.foreground, [false, true]);
      await tester.tap(find.text('Settings').last);
      await tester.pump(const Duration(milliseconds: 250));

      expect(state.foreground, [false, true]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(state.foreground.last, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      expect(state.foreground.last, isFalse);
      expect(state.foreground, [false, true, false, true, false]);
    },
  );
}
