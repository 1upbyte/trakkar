import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/screens/settings_screen.dart';

// Launch the real Settings screen without provisioning or a tracking server.
// Keep native platform views and preferences intact for the XCUITest.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.satelliteZoom =
      await SharedPreferencesAsync().getDouble('map.satelliteZoom') ?? 19;
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ),
  );
}
