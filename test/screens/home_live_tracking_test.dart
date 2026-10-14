import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/screens/home_screen.dart';

class _VisibilityState extends AppState {
  final foreground = <bool>[];
  final mapVisibility = <bool>[];

  @override
  void setAppForeground(bool visible) {
    foreground.add(visible);
  }

  @override
  void setMapVisible(bool visible) {
    mapVisibility.add(visible);
  }

  @override
  Future<void> refreshTrackingHealth() async {}
}

void main() {
  testWidgets(
    'background launches stay inactive and only the Map tab requests viewing',
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
      expect(state.mapVisibility.last, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(state.foreground.last, isTrue);
      await tester.tap(find.text('People').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.mapVisibility.last, isFalse);
      await tester.tap(find.text('Map').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.mapVisibility.last, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(state.foreground.last, isFalse);
      expect(state.mapVisibility.last, isFalse);
    },
  );
}
