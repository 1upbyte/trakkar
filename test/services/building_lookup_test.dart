import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/services/building_lookup.dart';

final fixture = File('test/fixtures/grand_central_buildings.mvt')
    .readAsBytesSync();
const tile = TileKey(14, 4825, 6157);
const terminal = LatLng(40.7527, -73.9772);

class TestProvider extends VectorTileProvider {
  int calls = 0;
  bool fail = false;
  @override
  int get maximumZoom => 14;
  @override
  int get minimumZoom => 0;
  @override
  String get cacheKey => 'test-buildings';
  @override
  Future<TileResponse> load(
    TileKey tile, {
    CancellationToken? cancellation,
  }) async {
    calls++;
    return fail
        ? TileResponseError(Exception('Offline'))
        : TileResponseData(fixture);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real map tile selects Grand Central and fills its name', () {
    final buildings = decodeBuildingTile(fixture, tile);
    final selected = buildings.where((b) => b.contains(terminal)).single;
    expect(selected.name, 'Grand Central Terminal');
    expect(selected.boundary, hasLength(8));
    expect(buildings.length, greaterThan(1));
    // Real map tiles group independent buildings under a shared feature ID.
    expect(buildings.map((b) => b.id).toSet().length, buildings.length);
    expect(BuildingLookup.tileAt(terminal, 14), tile);
  });

  test(
    'visible outlines load once, share in-flight work, and filter the viewport',
    () async {
      final provider = TestProvider();
      final lookup = BuildingLookup();
      final bounds = LatLngBounds(
        const LatLng(40.752, -73.978),
        const LatLng(40.754, -73.976),
      );
      final results = await Future.wait([
        lookup.inBounds(provider, bounds),
        lookup.inBounds(provider, bounds),
      ]);
      expect(provider.calls, 1);
      expect(results.first.any((b) => b.contains(terminal)), isTrue);
      expect(
        results.first.every(
          (b) => LatLngBounds.fromPoints(b.boundary).isOverlapping(bounds),
        ),
        isTrue,
      );
      await lookup.inBounds(provider, bounds);
      expect(provider.calls, 1);
    },
  );

  test(
    'failed loads can retry and wide views do not fetch thousands of tiles',
    () async {
      final provider = TestProvider()..fail = true;
      final lookup = BuildingLookup();
      final bounds = LatLngBounds(
        const LatLng(40.752, -73.978),
        const LatLng(40.754, -73.976),
      );
      await expectLater(
        lookup.inBounds(provider, bounds),
        throwsFormatException,
      );
      provider.fail = false;
      expect(await lookup.inBounds(provider, bounds), isNotEmpty);
      expect(provider.calls, 2);
      await expectLater(
        lookup.inBounds(
          provider,
          LatLngBounds(const LatLng(30, -80), const LatLng(50, -60)),
        ),
        throwsFormatException,
      );
      expect(provider.calls, 2);
    },
  );

  test(
    'implicit MVT ring closure and courtyard holes are decoded correctly',
    () {
      final buildings = decodeBuildingTile(
        courtyardTile(),
        const TileKey(0, 0, 0),
      );
      expect(buildings, hasLength(1));
      expect(buildings.single.boundary, hasLength(4));
      expect(buildings.single.holes, hasLength(1));
      expect(buildings.single.contains(const LatLng(0, 0)), isFalse);
      expect(buildings.single.contains(const LatLng(70, 0)), isTrue);
    },
  );

  test('keeps a single footprint and encloses multiple selected buildings', () {
    const square = [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)];
    const a = BuildingFootprint(id: 'a', boundary: square);
    const b = BuildingFootprint(
      id: 'b',
      boundary: [LatLng(0, 2), LatLng(0, 3), LatLng(1, 3), LatLng(1, 2)],
    );
    expect(buildingBoundary([a]), square);
    expect(polygonArea(buildingBoundary([a, b])), 3);
    expect(buildingBoundary([]), isEmpty);
  });
}

List<int> varint(int value) {
  final bytes = <int>[];
  while (value > 127) {
    bytes.add((value & 127) | 128);
    value >>= 7;
  }
  return [...bytes, value];
}

List<int> message(int field, List<int> bytes) => [
  ...varint((field << 3) | 2),
  ...varint(bytes.length),
  ...bytes,
];

Uint8List courtyardTile() {
  final commands = <int>[];
  var x = 0;
  var y = 0;
  for (final ring in [
    [(0, 0), (4096, 0), (4096, 4096), (0, 4096)],
    [(1024, 1024), (1024, 3072), (3072, 3072), (3072, 1024)],
  ]) {
    for (var i = 0; i < ring.length; i++) {
      if (i == 0) commands.add(9);
      if (i == 1) commands.add(26);
      final dx = ring[i].$1 - x;
      final dy = ring[i].$2 - y;
      commands.addAll([(dx << 1) ^ (dx >> 31), (dy << 1) ^ (dy >> 31)]);
      x = ring[i].$1;
      y = ring[i].$2;
    }
    commands.add(15);
  }
  final feature = [
    8,
    1,
    24,
    3,
    ...message(4, commands.expand(varint).toList()),
  ];
  final layer = [
    ...message(1, 'building'.codeUnits),
    ...message(2, feature),
    40,
    ...varint(4096),
    120,
    2,
  ];
  return Uint8List.fromList(message(3, layer));
}
