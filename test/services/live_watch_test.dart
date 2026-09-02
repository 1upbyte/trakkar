import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/traccar_device.dart';
import 'package:trakkar/services/live_watch.dart';

TraccarDevice _device(String uniqueId, {DateTime? watchUntil}) {
  return TraccarDevice(
    id: uniqueId.hashCode,
    name: uniqueId,
    uniqueId: uniqueId,
    status: 'online',
    raw: {
      'attributes': {
        if (watchUntil != null)
          TraccarDevice.watchUntilAttribute: watchUntil.millisecondsSinceEpoch,
      },
    },
  );
}

void main() {
  test('device watch attribute parses numbers and strings', () {
    final until = DateTime.utc(2030, 1, 1);
    expect(
      _device('a', watchUntil: until).watchUntil,
      until,
    );
    final asString = TraccarDevice(
      id: 1,
      name: 'a',
      uniqueId: 'a',
      status: 'online',
      raw: {
        'attributes': {
          TraccarDevice.watchUntilAttribute: '${until.millisecondsSinceEpoch}',
        },
      },
    );
    expect(asString.watchUntil, until);
    expect(asString.isWatchingAt(DateTime.utc(2029)), isTrue);
    expect(asString.isWatchingAt(DateTime.utc(2031)), isFalse);
    expect(_device('b').watchUntil, isNull);
  });

  test('watching publishes heartbeats and clears on exit', () {
    fakeAsync((async) {
      final published = <DateTime?>[];
      var sends = 0;
      final coordinator = LiveWatchCoordinator(
        publishWatch: (until) async => published.add(until),
        fetchDevices: () async => const [],
        sendPosition: () async {
          sends += 1;
          return true;
        },
        ownUniqueId: () => 'me',
        clock: () => DateTime.utc(2030, 1, 1).add(async.elapsed),
      );

      coordinator.setWatching(true);
      async.flushMicrotasks();
      expect(published, hasLength(1));
      expect(
        published.single,
        DateTime.utc(2030, 1, 1).add(coordinator.watchTtl),
      );
      expect(sends, 1);

      async.elapse(coordinator.heartbeatInterval * 2);
      expect(published, hasLength(3));

      coordinator.setWatching(false);
      async.flushMicrotasks();
      expect(published.last, isNull);

      async.elapse(coordinator.heartbeatInterval * 2);
      expect(published, hasLength(4));
    });
  });

  test('polling sends a position while another device is watching', () {
    fakeAsync((async) {
      final now = DateTime.utc(2030, 1, 1);
      var fetches = 0;
      var sends = 0;
      var someoneWatching = true;
      final coordinator = LiveWatchCoordinator(
        publishWatch: (_) async {},
        fetchDevices: () async {
          fetches += 1;
          return [
            _device('me', watchUntil: now.add(const Duration(hours: 1))),
            _device(
              'friend',
              watchUntil: someoneWatching
                  ? now.add(const Duration(hours: 1))
                  : null,
            ),
          ];
        },
        sendPosition: () async {
          sends += 1;
          return true;
        },
        ownUniqueId: () => 'me',
        clock: () => now.add(async.elapsed),
      );

      coordinator.startPolling();
      async.elapse(Duration.zero);
      expect(fetches, 1);
      expect(coordinator.watchers, ['friend']);
      expect(sends, 1);

      // Watched: fast cadence, and each poll sends at most one position
      // per minimum gap.
      async.elapse(coordinator.watchedPollInterval);
      expect(fetches, 2);
      expect(sends, 2);

      someoneWatching = false;
      async.elapse(coordinator.watchedPollInterval);
      expect(fetches, 3);
      expect(coordinator.watchers, isEmpty);
      expect(sends, 2);

      // Idle: slow cadence and no uploads.
      async.elapse(coordinator.watchedPollInterval);
      expect(fetches, 3);
      async.elapse(coordinator.idlePollInterval - coordinator.watchedPollInterval);
      expect(fetches, 4);
      expect(sends, 2);

      coordinator.stopPolling();
      async.elapse(coordinator.idlePollInterval * 3);
      expect(fetches, 4);
    });
  });

  test('own watch attribute never counts as being watched', () {
    fakeAsync((async) {
      final now = DateTime.utc(2030, 1, 1);
      var sends = 0;
      final coordinator = LiveWatchCoordinator(
        publishWatch: (_) async {},
        fetchDevices: () async => const [],
        sendPosition: () async {
          sends += 1;
          return true;
        },
        ownUniqueId: () => 'me',
        clock: () => now,
      );

      coordinator.observeDevices([
        _device('me', watchUntil: now.add(const Duration(minutes: 1))),
        _device('stale', watchUntil: now.subtract(const Duration(minutes: 1))),
      ]);
      async.flushMicrotasks();

      expect(coordinator.watchers, isEmpty);
      expect(sends, 0);
    });
  });
}
