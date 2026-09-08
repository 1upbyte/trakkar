import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/traccar_position.dart';

void main() {
  test('offline, invalid, and delayed updates retain the last usable fix', () {
    TraccarPosition position(int id, int minute, {bool valid = true}) =>
        TraccarPosition(
          id: id,
          deviceId: 1,
          latitude: 40,
          longitude: -74,
          valid: valid,
          fixTime: DateTime.utc(2026, 9, 7, 12, minute),
        );
    final last = position(1, 10);
    expect(mergeLastKnownPositions({1: last}, [])[1], same(last));
    expect(
      mergeLastKnownPositions({1: last}, [position(2, 11, valid: false)])[1],
      same(last),
    );
    expect(mergeLastKnownPositions({1: last}, [position(3, 9)])[1], same(last));
    final newest = position(4, 12);
    expect(mergeLastKnownPositions({1: last}, [newest])[1], same(newest));
  });
}
