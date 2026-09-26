import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'services/auth/secure_session_store.dart';
import 'services/auth/setup_controller.dart';
import 'services/auth/traccar_auth_service.dart';
import 'app/app_theme.dart';
import 'services/settings/preferences_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = SetupController(
    service: TraccarAuthService(),
    store: SecureSessionStore(),
  );
  final preferences = PreferencesRepository();
  final themeController = AppThemeController(preferences: preferences);
  runApp(
    TrakkarApp(
      controller: controller,
      themeController: themeController,
      preferences: preferences,
    ),
  );
  unawaited(controller.restoreSession());
}

class TrakkarApp extends StatefulWidget {
  const TrakkarApp({
    required this.controller,
    required this.themeController,
    required this.preferences,
    super.key,
  });

  final SetupController controller;
  final AppThemeController themeController;
  final PreferencesRepository preferences;

  @override
  State<TrakkarApp> createState() => _TrakkarAppState();
}

class _TrakkarAppState extends State<TrakkarApp> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.themeController.load());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.themeController,
    builder: (context, _) => MaterialApp(
      title: 'Trakkar',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: widget.themeController.themeMode,
      home: AppRouter(
        controller: widget.controller,
        themeController: widget.themeController,
        preferences: widget.preferences,
      ),
    ),
  );
}
