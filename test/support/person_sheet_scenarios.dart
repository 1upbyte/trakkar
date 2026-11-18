import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/main.dart';
import 'package:trakkar/widgets/liquid_glass.dart';

import 'person_sheet_state.dart';

Future<void> launchPersonMap(WidgetTester tester) async {
  final state = PersonSheetState();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const TrakkarApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> openPersonSheet(WidgetTester tester) async {
  await launchPersonMap(tester);
  await tester.tap(find.text('A').first);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder personSheetList() => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.identifier == 'person-pane-content',
  ),
  matching: find.byType(ListView),
);

Finder personSheetDragHandle() =>
    find.byKey(const ValueKey('person-pane-drag-handle'));

Finder _positionSummary() => find.descendant(
  of: personSheetList(),
  matching: find.text('Time unknown  •  0 mph'),
);

void expectPersonPaneFitsContent(WidgetTester tester) {
  final viewport = tester.getRect(personSheetList());
  expect(
    viewport.bottom - tester.getRect(_positionSummary()).bottom,
    closeTo(24, 1),
    reason: 'Only the list padding should follow the time and speed',
  );
}

Future<void> scrollPersonSheetToSummary(WidgetTester tester) async {
  await tester.drag(personSheetList(), const Offset(0, -500));
  // Start any iOS overscroll animation before advancing its elapsed time.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(personSheetList(), findsOneWidget);
  await tester.scrollUntilVisible(
    _positionSummary(),
    100,
    scrollable: find.descendant(
      of: personSheetList(),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  expectPersonSummaryVisible(tester);
}

void expectPersonSummaryVisible(WidgetTester tester) {
  final summary = _positionSummary();
  expect(summary, findsOneWidget);
  final viewport = tester.getRect(personSheetList());
  final summaryRect = tester.getRect(summary);
  expect(summaryRect.top, greaterThanOrEqualTo(viewport.top));
  expect(summaryRect.bottom, lessThanOrEqualTo(viewport.bottom));
  final navigation = find.byType(LiquidGlassTabBar).evaluate().isNotEmpty
      ? find.byType(LiquidGlassTabBar)
      : find.byType(NavigationBar);
  expect(viewport.bottom, lessThanOrEqualTo(tester.getRect(navigation).top));
  if (find.byType(LiquidGlassTabBar).evaluate().isNotEmpty) {
    final surface = find.ancestor(
      of: personSheetList(),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.borderRadius ==
                const BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
    expect(
      tester.getRect(surface).bottom,
      closeTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
        1,
      ),
    );
    // The glass menu must stay above the surface and remain interactive.
    expect(find.text('People').last.hitTestable(), findsOneWidget);
  }
  expect(tester.takeException(), isNull);
}
