import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/screens/settings_screen.dart';

void main() {
  testWidgets(
    'map switches save immediately and permanent mode disables threshold',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = AppState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.scrollUntilVisible(find.text('Dark map'), 300);
      await tester.tap(find.text('Dark map'));
      await tester.pumpAndSettle();
      expect(state.darkMap, isTrue);
      expect(await SharedPreferencesAsync().getBool('map.darkMode'), isTrue);
      expect(find.text('Save map appearance'), findsNothing);
      await tester.scrollUntilVisible(find.text('Always satellite'), 200);
      await tester.tap(find.text('Always satellite'));
      await tester.pumpAndSettle();
      expect(state.satelliteAlways, isTrue);
      await tester.scrollUntilVisible(find.byType(Slider), 150);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    },
  );
}
