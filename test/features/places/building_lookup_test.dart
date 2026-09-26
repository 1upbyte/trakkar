import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_tile/raw/raw_vector_tile.dart' as raw;
import 'package:trakkar/features/places/building_lookup.dart';

Uint8List tileBytes({
  String layerName = 'building',
  List<int>? geometry,
  int featureCount = 1,
  bool polygon = true,
}) {
  final shape = geometry ?? [9, 200, 200, 26, 1600, 0, 0, 1600, 1599, 0, 15];
  final features = [
    for (var i = 0; i < featureCount; i++)
      raw.VectorTile_Feature(
        id: Int64(17),
        tags: [0, 0],
        type: polygon
            ? raw.VectorTile_GeomType.POLYGON
            : raw.VectorTile_GeomType.POINT,
        geometry: shape,
      ),
  ];
  final layer = raw.VectorTile_Layer(
    name: layerName,
    version: 2,
    extent: 4096,
    keys: ['name'],
    values: [raw.VectorTile_Value(stringValue: 'Library')],
    features: features,
  );
  return Uint8List.fromList(raw.VectorTile(layers: [layer]).writeToBuffer());
}

class _Provider extends vt.VectorTileProvider {
  _Provider(this.bytes);
  final Uint8List bytes;
  int loads = 0;

  @override
  String get cacheKey => 'test-building-tiles';
  @override
  int get maximumZoom => 18;
  @override
  int get minimumZoom => 0;

  @override
  Future<vt.TileResponse> load(
    vt.TileKey tile, {
    vt.CancellationToken? cancellation,
  }) async {
    loads++;
    return vt.TileResponseData(bytes);
  }
}

vt.Style style(vt.VectorTileProvider provider) => vt.Style(
  theme: const vt.Theme(id: 'test', layers: []),
  providers: vt.TileProviders({'openmaptiles': provider}),
);

void main() {
  test('selects only polygon features from the building source layer', () {
    final decoded = BuildingLookup.decodeTile(
      tileBytes(),
      const vt.TileKey(15, 16384, 16384),
    );
    expect(decoded, hasLength(1));
    expect(decoded.single.name, 'Library');
    expect(decoded.single.points.length, greaterThanOrEqualTo(3));
    expect(decoded.single.contains(decoded.single.points[0]), isTrue);
  });

  test(
    'deduplicates repeated tile features by their stable geometry identity',
    () async {
      final provider = _Provider(tileBytes(featureCount: 2));
      final lookup = BuildingLookup(
        style: style(provider),
        sourceId: 'openmaptiles',
      );
      final result = await lookup.lookup(
        bounds: LatLngBounds(
          const LatLng(0.01, -0.01),
          const LatLng(-0.01, 0.01),
        ),
        displayZoom: 16,
      );
      expect(result.candidates, hasLength(1));
    },
  );

  test('rejects invalid and non-polygon building geometry', () {
    final collinear = [9, 0, 0, 26, 100, 100, 100, 100, 100, 100, 15];
    expect(
      BuildingLookup.decodeTile(
        tileBytes(geometry: collinear),
        const vt.TileKey(15, 16384, 16384),
      ),
      isEmpty,
    );
    expect(
      BuildingLookup.decodeTile(
        tileBytes(polygon: false),
        const vt.TileKey(15, 16384, 16384),
      ),
      isEmpty,
    );
  });

  test(
    'an absent source layer and zoom below 16 make no tile requests',
    () async {
      final noLayerProvider = _Provider(tileBytes(layerName: 'transportation'));
      final noLayer =
          await BuildingLookup(
            style: style(noLayerProvider),
            sourceId: 'openmaptiles',
          ).lookup(
            bounds: LatLngBounds(
              const LatLng(0.01, -0.01),
              const LatLng(-0.01, 0.01),
            ),
            displayZoom: 16,
          );
      expect(noLayer.candidates, isEmpty);

      final lowZoomProvider = _Provider(tileBytes());
      final tooFar =
          await BuildingLookup(
            style: style(lowZoomProvider),
            sourceId: 'openmaptiles',
          ).lookup(
            bounds: LatLngBounds(
              const LatLng(0.01, -0.01),
              const LatLng(-0.01, 0.01),
            ),
            displayZoom: 15.99,
          );
      expect(tooFar.candidates, isEmpty);
      expect(lowZoomProvider.loads, 0);
    },
  );

  test('tile request failures are reported for manual fallback', () async {
    final provider = _Provider(tileBytes());
    final lookup = BuildingLookup(
      style: style(provider),
      sourceId: 'openmaptiles',
      tileLoader: (_, _) async => const vt.TileResponseError('offline'),
    );
    final result = await lookup.lookup(
      bounds: LatLngBounds(
        const LatLng(0.01, -0.01),
        const LatLng(-0.01, 0.01),
      ),
      displayZoom: 16,
    );
    expect(result.hadTileFailure, isTrue);
    expect(result.message, contains('could not be loaded'));
  });
}
