import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/main.dart';

import '../../test/support/person_sheet_state.dart';

// Exercise the real app shell, map, pane, and native glass on the simulator
// without provisioning an account or connecting to a tracking server.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep Flutter semantics available to XCUITest when VoiceOver is off.
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => PersonSheetState(),
      child: const TrakkarApp(),
    ),
  );
}
