import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/features/settings/appearance_settings_section.dart';
import 'package:trakkar/models/map_appearance_preference.dart';
import 'package:trakkar/models/theme_preference.dart';

void main() {
  testWidgets(
    'offers System, Light, Dark and the default satellite threshold',
    (tester) async {
      var theme = AppThemePreference.system;
      var threshold = 19.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppearanceSettingsSection(
                themePreference: theme,
                mapAppearance: MapAppearancePreference(
                  satelliteThresholdZoom: threshold,
                ),
                onThemeChanged: (value) => setState(() => theme = value),
                onThresholdChanged: (value) =>
                    setState(() => threshold = value),
              ),
            ),
          ),
        ),
      );
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Switch to satellite at zoom 19'), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(theme, AppThemePreference.dark);
    },
  );
}
