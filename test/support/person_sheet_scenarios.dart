import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/main.dart';
import 'package:trakkar/models/traccar_device.dart';
import 'package:trakkar/models/traccar_position.dart';
import 'package:trakkar/widgets/liquid_glass.dart';

class PersonSheetState extends AppState {
  PersonSheetState() {
    phase = AppPhase.ready;
    devices = const [
      TraccarDevice(
        id: 1,
        name: 'Alex',
        uniqueId: 'sheet-test',
        status: 'online',
        raw: {},
      ),
    ];
    positions = const {
      1: TraccarPosition(
        id: 1,
        deviceId: 1,
        latitude: 40.7527,
        longitude: -73.9772,
        valid: true,
        address: 'Grand Central Terminal, New York',
      ),
    };
  }

  @override
  void setAppForeground(bool visible) {}

  @override
  Future<void> refreshTrackingHealth() async {}
}

Future<void> openPersonSheet(WidgetTester tester) async {
  final state = PersonSheetState();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const TrakkarApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('A').first);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder personSheetList() => find.descendant(
  of: find.byType(DraggableScrollableSheet),
  matching: find.byType(ListView),
);

Future<void> expandPersonSheet(WidgetTester tester) async {
  await tester.drag(personSheetList(), const Offset(0, -500));
  await tester.pump(const Duration(seconds: 1));
  await tester.scrollUntilVisible(
    find.text('Give this place a friendly name'),
    100,
    scrollable: find.descendant(
      of: personSheetList(),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  expectPersonActionVisible(tester);
}

void expectPersonActionVisible(WidgetTester tester) {
  final action = find.text('Give this place a friendly name');
  expect(action, findsOneWidget);
  final viewport = tester.getRect(personSheetList());
  final actionRect = tester.getRect(action);
  expect(actionRect.top, greaterThanOrEqualTo(viewport.top));
  expect(actionRect.bottom, lessThanOrEqualTo(viewport.bottom));
  final navigation = find.byType(LiquidGlassTabBar).evaluate().isNotEmpty
      ? find.byType(LiquidGlassTabBar)
      : find.byType(NavigationBar);
  expect(viewport.bottom, lessThanOrEqualTo(tester.getRect(navigation).top));
  expect(action.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}
