import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/models/provisioning_config.dart';
import 'package:trakkar/screens/settings_screen.dart';
import 'package:trakkar/screens/setup_qr_dialog.dart';

void main() {
  testWidgets(
    'settings QR preserves full setup and requires explicit sharing',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final config = ProvisioningConfig.fromFields(
        clientUrl: 'https://client.test',
        managerUrl: 'https://manager.test',
        liveTrackingUrl: 'https://live.test',
        managerUsername: 'friend',
        managerPassword: 'secret;+ café',
      );
      final state = AppState()..provisioning = config;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.scrollUntilVisible(find.text('Share QR code'), 400);
      expect(find.text('Copy setup link'), findsOneWidget);
      await tester.tap(find.text('Share QR code'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<SetupQrDialog>(find.byType(SetupQrDialog));
      expect(dialog.config.toStorage(), config.toStorage());
      expect(find.textContaining('manager login and password'), findsOneWidget);
      expect(find.text('Share image'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
    },
  );
}
