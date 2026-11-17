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
        expectPersonActionVisible(tester);
        await expandPersonSheet(tester);
        await tester.tap(find.text('People').last);
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        await tester.tap(find.text('Map').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('A').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expectPersonActionVisible(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets('small landscape pane scrolls to its bottom with large text', (
    tester,
  ) async {
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
    await expandPersonSheet(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
    await expandPersonSheet(tester);
    await tester.tap(find.text('Give this place a friendly name'));
    await tester.pumpAndSettle();
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
    expectPersonActionVisible(tester);
    await tester.tap(find.text('People').last);
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
