import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/models/provisioning_config.dart';
import 'package:trakkar/screens/setup_link_screen.dart';

class _SetupState extends AppState {
  int logins = 0;
  int resets = 0;
  String? receivedLiveUrl;

  @override
  Future<void> acceptManual({
    required String clientUrl,
    required String managerUrl,
    required String managerUsername,
    required String managerPassword,
    String liveTrackingUrl = '',
  }) async {
    logins++;
    receivedLiveUrl = liveTrackingUrl;
  }

  @override
  Future<void> resetApp() async {
    resets++;
    phase = AppPhase.onboarding;
    notifyListeners();
  }
}

void main() {
  late _SetupState state;
  late String link;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    state = _SetupState()..phase = AppPhase.onboarding;
    link = ProvisioningConfig.fromFields(
      clientUrl: 'https://client.test',
      managerUrl: 'https://manager.test',
      liveTrackingUrl: 'https://live.test',
      managerUsername: 'friend',
      managerPassword: 'secret',
    ).toSetupLink().toString();
  });

  tearDown(() => state.dispose());

  Future<void> open(WidgetTester tester, String value) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(home: SetupLinkScreen(link: value)),
      ),
    );
  }

  testWidgets('requires review and Connect before login', (tester) async {
    await open(tester, link);
    expect(state.logins, 0);
    expect(find.text('secret'), findsNothing);
    await tester.tap(find.text('Continue to login'));
    await tester.pumpAndSettle();
    expect(state.logins, 0);
    expect(state.resets, 0);
    await tester.ensureVisible(find.text('Connect'));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(state.logins, 1);
    expect(state.receivedLiveUrl, 'https://live.test');
  });

  testWidgets('existing setup is replaced only after explicit confirmation', (
    tester,
  ) async {
    state.phase = AppPhase.ready;
    await open(tester, link);
    expect(find.text('Replace setup and continue'), findsOneWidget);
    expect(state.resets, 0);
    expect(state.logins, 0);
    await tester.tap(find.text('Replace setup and continue'));
    await tester.pumpAndSettle();
    expect(state.resets, 1);
    expect(state.logins, 0);
  });

  testWidgets('malformed links show a safe error', (tester) async {
    await open(tester, 'trakkar://setup?data=invalid');
    expect(find.text('This setup link is invalid or incomplete.'), findsOneWidget);
    expect(state.logins, 0);
    expect(state.resets, 0);
  });
}
