import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/models/provisioning_config.dart';
import 'package:trakkar/models/traccar_device.dart';
import 'package:trakkar/screens/onboarding_screen.dart';

class _TakeoverState extends AppState {
  final attempts = <bool>[];

  @override
  Future<void> completeProfile({
    required String firstName,
    required String username,
    bool replace = false,
  }) async {
    attempts.add(replace);
    if (!replace) {
      throw DeviceConflictException(
        TraccarDevice.fromJson({
          'id': 12,
          'name': 'Pablo',
          'uniqueId': 'pablo-phone',
        }),
      );
    }
  }
}

void main() {
  late _TakeoverState state;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    state = _TakeoverState()
      ..phase = AppPhase.onboarding
      ..pendingProvisioning = ProvisioningConfig.fromFields(
        clientUrl: 'https://client.test',
        managerUrl: 'https://manager.test',
        liveTrackingUrl: 'https://live.test',
        managerUsername: 'shared',
        managerPassword: 'secret',
      );
  });

  tearDown(() => state.dispose());

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'First name'),
      'Pablo',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Username'),
      'pablo-phone',
    );
    await tester.ensureVisible(find.text('Start sharing'));
    await tester.tap(find.text('Start sharing'));
    await tester.pumpAndSettle();
  }

  testWidgets('duplicate username warning can be cancelled without takeover', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Username already in use'), findsOneWidget);
    expect(
      find.textContaining('Its history and sharing will be kept.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Choose another'));
    await tester.pumpAndSettle();
    expect(state.attempts, [false]);
  });

  testWidgets('only confirmation retries signup with takeover enabled', (
    tester,
  ) async {
    await start(tester);
    expect(state.attempts, [false]);
    await tester.tap(find.text('Use on this phone'));
    await tester.pumpAndSettle();
    expect(state.attempts, [false, true]);
  });
}
