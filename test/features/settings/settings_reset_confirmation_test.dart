import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/app/app_theme.dart';
import 'package:trakkar/features/settings/settings_screen.dart';
import 'package:trakkar/models/map_appearance_preference.dart';
import 'package:trakkar/models/server_details.dart';
import 'package:trakkar/services/settings/preferences_repository.dart';

void main() {
  testWidgets(
    'canceling reset is mutation-free and confirmation invokes reset',
    (tester) async {
      var resetCount = 0;
      final preferences = PreferencesRepository();
      final theme = AppThemeController(preferences: preferences);
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            state: null,
            themeController: theme,
            serverDetails: const ServerDetails(
              clientUrl: null,
              managerUrl: null,
              accountName: null,
            ),
            mapAppearance: const MapAppearancePreference(),
            onThresholdChanged: (_) {},
            onReset: () async {
              resetCount++;
            },
            onProfileChanged: () {},
          ),
        ),
      );

      await tester.pumpWidget(screen());
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(resetCount, 0);

      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset app'));
      await tester.pumpAndSettle();
      expect(resetCount, 1);
      theme.dispose();
    },
  );
}
