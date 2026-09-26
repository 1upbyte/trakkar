import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'services/auth/secure_session_store.dart';
import 'services/auth/setup_controller.dart';
import 'services/auth/traccar_auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = SetupController(
    service: TraccarAuthService(),
    store: SecureSessionStore(),
  );
  runApp(TrakkarApp(controller: controller));
  unawaited(controller.restoreSession());
}

class TrakkarApp extends StatelessWidget {
  const TrakkarApp({required this.controller, super.key});

  final SetupController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Trakkar',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: AppRouter(controller: controller),
  );
}
