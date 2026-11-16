import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/widgets/ios_system_control.dart';

void main() {
  testWidgets(
    'native changes use the current callback and stop after disposal',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final updates = <Map<Object?, Object?>>[];
      late String channelName;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          channelName =
              'com.oneupbyte.trakkar/system-control/${arguments['id']}';
          messenger.setMockMethodCallHandler(MethodChannel(channelName), (
            call,
          ) async {
            if (call.method == 'update') {
              updates.add(call.arguments as Map<Object?, Object?>);
            }
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        messenger.setMockMethodCallHandler(MethodChannel(channelName), null);
      });
      final first = <Object?>[];
      final second = <Object?>[];
      Widget control(ValueChanged<Object?>? changed, bool value) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: 64,
            height: 44,
            child: IOSSystemControl(
              kind: 'switch',
              configuration: {'value': value},
              onChanged: changed,
            ),
          ),
        ),
      );
      Future<void> nativeChange(Object value) async {
        await messenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('changed', value),
          ),
          (_) {},
        );
      }

      await tester.pumpWidget(control(first.add, false));
      await tester.pumpAndSettle();
      await nativeChange(true);
      expect(first, [true]);
      await tester.pumpWidget(control(second.add, true));
      await tester.pumpAndSettle();
      expect(updates.last['value'], true);
      await nativeChange(false);
      expect(first, [true]);
      expect(second, [false]);
      await tester.pumpWidget(control(null, false));
      await tester.pumpAndSettle();
      expect(updates.last['enabled'], false);
      await nativeChange(true);
      expect(second, [false]);
      await tester.pumpWidget(const SizedBox.shrink());
      await nativeChange(true);
      expect(second, [false]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
