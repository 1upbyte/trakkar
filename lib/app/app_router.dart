import 'package:flutter/material.dart';

import '../models/setup_attempt.dart';
import '../services/auth/setup_controller.dart';
import '../features/setup/manual_setup_screen.dart';
import '../features/setup/setup_choice_screen.dart';
import 'app_shell.dart';
import '../features/setup/setup_recovery_view.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({required this.controller, super.key});

  final SetupController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.isRestoringSession) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (controller.hasAuthenticatedSession || controller.isProceedingAnyway) {
        return AppShell(controller: controller);
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
