import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/models/provisioning_config.dart';
import 'package:trakkar/screens/onboarding_screen.dart';

class _ScanState extends AppState {
  int logins = 0;
  ProvisioningConfig? received;
  final login = Completer<void>();

  @override
  Future<void> acceptManual({
    required String clientUrl,
    required String managerUrl,
    required String managerUsername,
    required String managerPassword,
    String liveTrackingUrl = '',
  }) async {
    logins++;
    received = ProvisioningConfig.fromFields(
      clientUrl: clientUrl,
      managerUrl: managerUrl,
      liveTrackingUrl: liveTrackingUrl,
      managerUsername: managerUsername,
      managerPassword: managerPassword,
    );
    await login.future;
    pendingProvisioning = received;
    notifyListeners();
  }
}

void main() {
  testWidgets('shared QR connects once and advances directly to profile', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final state = _ScanState()..phase = AppPhase.onboarding;
    addTearDown(state.dispose);
    final config = ProvisioningConfig.fromFields(
      clientUrl: 'https://client.test',
      managerUrl: 'https://manager.test',
      liveTrackingUrl: 'https://live.test',
      managerUsername: 'friend',
      managerPassword: 'secret;+ café',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    expect(find.text('Setup link'), findsNothing);
    expect(find.text('Use setup link'), findsNothing);
    await tester.tap(find.text('Scan server code'));
    await tester.pump();
    final onDetect = tester
        .widget<MobileScanner>(find.byType(MobileScanner))
        .onDetect!;
    final capture = BarcodeCapture(
      barcodes: [Barcode(rawValue: config.toSetupLink().toString())],
    );
    onDetect(capture);
    onDetect(capture);
    expect(state.logins, 1);
    expect(state.received!.toStorage(), config.toStorage());
    state.login.complete();
    await tester.pumpAndSettle();
    expect(find.text('Make it yours'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    expect(find.text('Log in with this setup?'), findsNothing);
    onDetect(capture);
    expect(state.logins, 1);
  });
}
