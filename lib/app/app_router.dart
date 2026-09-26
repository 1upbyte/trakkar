import 'package:flutter/material.dart';

import '../models/setup_attempt.dart';
import '../services/auth/setup_controller.dart';
import '../services/settings/preferences_repository.dart';
import 'app_theme.dart';
import '../features/setup/manual_setup_screen.dart';
import '../features/setup/setup_choice_screen.dart';
import 'app_shell.dart';
import '../features/setup/setup_recovery_view.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({
    required this.controller,
    this.themeController,
    this.preferences,
    super.key,
  });

  final SetupController controller;
  final AppThemeController? themeController;
  final PreferencesRepository? preferences;

  static final _defaultPreferences = PreferencesRepository();
  static final _defaultTheme = AppThemeController(
    preferences: _defaultPreferences,
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.isRestoringSession) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (controller.hasAuthenticatedSession || controller.isProceedingAnyway) {
        return AppShell(
          controller: controller,
          themeController: themeController ?? _defaultTheme,
          preferences: preferences ?? _defaultPreferences,
        );
      }
      if (controller.state == SetupAttemptState.rejected ||
          controller.state == SetupAttemptState.unavailable) {
        return SetupRecoveryView(controller: controller);
      }
      if (controller.state == SetupAttemptState.editing ||
          controller.state == SetupAttemptState.authenticating) {
        return ManualSetupScreen(controller: controller);
      }
      return SetupChoiceScreen(controller: controller);
    },
  );
}
