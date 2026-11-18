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
    'one enabled satellite slider selects never, always, and automatic zoom',
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
      expect(find.text('Apple satellite (experimental)'), findsNothing);
      await tester.tap(find.text('Dark map'));
      await tester.pumpAndSettle();
      expect(state.darkMap, isTrue);
      expect(await SharedPreferencesAsync().getBool('map.darkMode'), isTrue);
      expect(find.text('Save map appearance'), findsNothing);
      await tester.scrollUntilVisible(find.byType(Slider), 150);
      await tester.ensureVisible(find.byType(Slider));
      await tester.pumpAndSettle();
      expect(find.text('Satellite at street level'), findsNothing);
      expect(find.text('Always satellite'), findsNothing);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);

      await tester.drag(find.byType(Slider), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      expect(find.text('Satellite: never'), findsOneWidget);
      expect(state.satelliteAtZoom(21), isFalse);
      expect(
        await SharedPreferencesAsync().getBool('map.satelliteAutoAtStreetZoom'),
        isFalse,
      );

      await tester.drag(find.byType(Slider), const Offset(1000, 0));
      await tester.pumpAndSettle();
      expect(find.text('Satellite: always'), findsOneWidget);
      expect(state.satelliteAlways, isTrue);
      expect(state.satelliteAtZoom(2), isTrue);
      expect(
        await SharedPreferencesAsync().getBool('map.satelliteAlways'),
        isTrue,
      );
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);

      await tester.tap(find.byType(Slider));
      await tester.pumpAndSettle();
      expect(state.satelliteAlways, isFalse);
      expect(state.satelliteAutoAtStreetZoom, isTrue);
      expect(state.satelliteZoom, inInclusiveRange(2, 21));
      expect(state.satelliteAtZoom(state.satelliteZoom - 0.5), isFalse);
      expect(state.satelliteAtZoom(state.satelliteZoom), isTrue);
    },
  );

  testWidgets('iOS Apple satellite is opt-in and persists independently', (
    tester,
  ) async {
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

    final toggle = find.text('Apple satellite (experimental)');
    await tester.scrollUntilVisible(toggle, 200);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
    expect(state.experimentalAppleSatellite, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(state.experimentalAppleSatellite, isTrue);
    expect(
      await SharedPreferencesAsync().getBool('map.experimentalAppleSatellite'),
      isTrue,
    );

    await state.saveMapAppearance(
      satelliteSliderValue: AppState.satelliteSliderMin,
    );
    await tester.pumpAndSettle();
    expect(state.experimentalAppleSatellite, isTrue);
    expect(state.satelliteAtZoom(21), isFalse);
      await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      await SharedPreferencesAsync().getBool('map.experimentalAppleSatellite'),
      isFalse,
    );
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
}
