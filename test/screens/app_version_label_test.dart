import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/screens/settings_screen.dart';
import 'package:trakkar/widgets/app_version_label.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    PackageInfo.setMockInitialValues(
      appName: 'Trakkar',
      packageName: 'com.oneupbyte.trakkar',
      version: '9.8.7',
      buildNumber: '246',
      buildSignature: '',
    );
  });

  testWidgets('Settings shows the installed iOS version and build', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version 9.8.7 · Build 246'), findsOneWidget);
  });

  testWidgets('Android shows the GitHub release name including punctuation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const AppVersionLabel(releaseName: 'Autumn update, #12 (beta)'),
      ),
    );
    expect(find.text('Release Autumn update, #12 (beta)'), findsOneWidget);
    expect(find.textContaining('Build 246'), findsNothing);
  });

  testWidgets('local Android builds fall back to the installed version', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const AppVersionLabel(releaseName: '  '),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version 9.8.7 · Build 246'), findsOneWidget);
  });

  testWidgets('iOS uses its build even when a release name was supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const AppVersionLabel(releaseName: 'Android release title'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version 9.8.7 · Build 246'), findsOneWidget);
    expect(find.textContaining('Android release title'), findsNothing);
  });
}
