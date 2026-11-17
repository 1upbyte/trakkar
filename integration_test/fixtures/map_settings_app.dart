import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/screens/settings_screen.dart';

// Launch the real Settings screen without provisioning or a tracking server.
// Keep native platform views and preferences intact for the XCUITest.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = SharedPreferencesAsync();
  final state = AppState();
  state.satelliteZoom = (await preferences.getDouble('map.satelliteZoom') ?? 19)
      .clamp(2, 21);
  state.satelliteAlways =
      await preferences.getBool('map.satelliteAlways') ?? false;
  state.satelliteAutoAtStreetZoom =
      await preferences.getBool('map.satelliteAutoAtStreetZoom') ?? true;
  state.darkMap = await preferences.getBool('map.darkMode') ?? false;
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        home: Scaffold(
          body: const SettingsScreen(),
          // Observe the map's real imagery decision without fetching map tiles.
          bottomNavigationBar: SafeArea(
            child: Consumer<AppState>(
              builder: (context, state, _) => Text(
                'Satellite at zoom 2: ${state.satelliteAtZoom(2) ? 'on' : 'off'}; '
                'at zoom 21: ${state.satelliteAtZoom(21) ? 'on' : 'off'}',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
