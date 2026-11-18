import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/person_sheet_scenarios.dart';

void main() {
  for (final size in [const Size(393, 852), const Size(375, 667)]) {
    testWidgets(
      'person pane opens without clipping at $size',
      (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
        tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
        addTearDown(tester.view.reset);
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        await openPersonSheet(tester);
        expect(find.text('Give this place a friendly name'), findsNothing);
        expectPersonSummaryVisible(tester);
        final initialHeight = tester.getSize(personSheetList()).height;
        expectPersonPaneFitsContent(tester);
        await scrollPersonSheetToSummary(tester);
        expectPersonPaneFitsContent(tester);
        expect(
          tester.getSize(personSheetList()).height,
          closeTo(initialHeight, 1),
        );
        await tester.tap(find.text('People').last);
        await tester.pumpAndSettle();
        expect(personSheetList(), findsNothing);
        await tester.tap(find.text('Map').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('A').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expectPersonSummaryVisible(tester);
        await tester.drag(personSheetDragHandle(), const Offset(0, 280));
        await tester.pumpAndSettle();
        expect(personSheetList(), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'small landscape pane scrolls to its bottom with large text',
    (tester) async {
      tester.view.physicalSize = const Size(1704, 960);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(left: 102, right: 102);
      tester.view.viewPadding = const FakeViewPadding(left: 102, right: 102);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await openPersonSheet(tester);
      await scrollPersonSheetToSummary(tester);
      await tester.drag(personSheetDragHandle(), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(personSheetList(), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('person pane keeps menu clearance after keyboard dismissal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
    addTearDown(tester.view.reset);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await openPersonSheet(tester);
    await tester.longPressAt(const Offset(100, 200));
    await tester.pumpAndSettle();
    expect(find.text('Name this place'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    tester.view.padding = const FakeViewPadding(top: 177);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    // Model the intermediate frames sent by iOS as the keyboard slides away.
    for (final bottom in [720.0, 450.0, 180.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: bottom);
      tester.view.padding = FakeViewPadding(
        top: 177,
        bottom: bottom == 0 ? 102 : 0,
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    expectPersonSummaryVisible(tester);
    await tester.tap(find.text('People').last);
    await tester.pumpAndSettle();
    expect(personSheetList(), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
