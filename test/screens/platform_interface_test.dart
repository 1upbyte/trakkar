import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/main.dart';
import 'package:trakkar/models/theme_preference.dart';
import 'package:trakkar/widgets/liquid_glass.dart';

class _InterfaceState extends AppState {
  @override
  void setAppForeground(bool visible) {}

  @override
  Future<void> refreshTrackingHealth() async {}
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform uses platform controls and saves appearance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = _InterfaceState()..phase = AppPhase.ready;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const TrakkarApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final ios = platform == TargetPlatform.iOS;
      expect(
        find.byType(LiquidGlassTabBar),
        ios ? findsOneWidget : findsNothing,
      );
      expect(find.byType(NavigationBar), ios ? findsNothing : findsOneWidget);
      if (ios) {
        final mapControl = tester.getRect(
          find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right),
        );
        final tabBar = tester.getRect(find.byType(LiquidGlassTabBar));
        expect(mapControl.bottom, lessThan(tabBar.top));
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
          isTrue,
        );
      } else {
        expect(find.byType(LiquidGlass), findsNothing);
      }
      await tester.tap(find.text('Settings').last);
      await tester.pump(const Duration(milliseconds: 300));
      if (ios) {
        final material = find.descendant(
          of: find.byType(LiquidGlassTabBar),
          matching: find.byType(LiquidGlass),
        );
        expect(tester.widget<LiquidGlass>(material).selectedIndex, 3);
      }
      expect(find.byType(CupertinoSwitch), ios ? findsWidgets : findsNothing);
      expect(find.byType(SwitchListTile), ios ? findsNothing : findsWidgets);
      await tester.scrollUntilVisible(find.text('Dark').last, 200);
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(state.themePreference, ThemePreference.dark);
      expect(
        Theme.of(tester.element(find.text('Dark').last)).brightness,
        Brightness.dark,
      );
      await tester.scrollUntilVisible(find.text('Dark map'), 200);
      await tester.tap(find.text('Dark map'));
      await tester.pumpAndSettle();
      expect(state.darkMap, isTrue);
      await tester.tap(find.text('Places').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(
        find.byType(CupertinoActionSheet),
        ios ? findsOneWidget : findsNothing,
      );
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      if (ios) {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Reset app'), 400);
        await tester.tap(find.text('Reset app'));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform onboarding supports setup link entry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _InterfaceState()..phase = AppPhase.onboarding;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const TrakkarApp(),
        ),
      );
      final ios = platform == TargetPlatform.iOS;
      expect(
        find.byType(CupertinoTextField),
        ios ? findsWidgets : findsNothing,
      );
      expect(find.byType(TextField), ios ? findsNothing : findsWidgets);
      final field = find.byType(EditableText).first;
      await tester.ensureVisible(field);
      await tester.enterText(field, 'invalid-setup');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(
        find.text('This setup link is invalid or incomplete.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }
}
