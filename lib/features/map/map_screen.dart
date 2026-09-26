import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../models/map_appearance_preference.dart';
import '../../models/map_view_state.dart';
import '../../models/person.dart';
import '../../models/saved_place.dart';
import '../../services/map/location_description.dart';
import '../../services/map/map_layer_config.dart';
import '../../services/traccar_data_repository.dart';
import '../../widgets/server_connection_banner.dart';
import 'map_camera_policy.dart';
import 'person_cluster_marker.dart';
import 'person_details_sheet.dart';
import 'person_marker.dart';
import 'place_labels_layer.dart';

class MapStyleSet {
  const MapStyleSet({required this.standard, this.satellite});

  final vt.Style standard;
  final vt.Style? satellite;
}

typedef MapStyleLoader = Future<MapStyleSet> Function(String? mapTilerKey);

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.repository,
    required this.satelliteThresholdZoom,
    required this.onSatelliteUnavailable,
    this.styleLoader,
    super.key,
  });

  final TraccarDataRepository? repository;
  final double satelliteThresholdZoom;
  final ValueChanged<bool> onSatelliteUnavailable;
  final MapStyleLoader? styleLoader;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _cameraPolicy = const MapCameraPolicy();
  final _placeLabels = const PlaceLabelsLayer();
  List<PersonMapEntry> _people = const [];
  List<SavedPlace> _places = const [];
  vt.Style? _standardStyle;
  vt.Style? _satelliteStyle;
  String? _mapTilerKey;
  double _zoom = 2;
  LatLng _center = const LatLng(20, 0);
  final _selection = MapSelectionState();
  bool _loading = true;
  bool _connectionFailed = false;
  bool _satelliteUnavailable = false;
  bool _satelliteNoticeDismissed = false;
  int _loadGeneration = 0;
  StreamSubscription<TraccarMapUpdate>? _updates;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    _standardStyle?.dispose();
    _satelliteStyle?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final screenSize = MediaQuery.sizeOf(context);
    await _updates?.cancel();
    setState(() {
      _loading = true;
      _connectionFailed = false;
      _satelliteUnavailable = false;
      _satelliteNoticeDismissed = false;
    });
    try {
      final repository = widget.repository;
      TraccarMapSnapshot? snapshot;
      var dataFailed = false;
      if (repository != null) {
        try {
          snapshot = await repository.loadMap();
        } on Object {
          dataFailed = true;
        }
      } else {
        _satelliteUnavailable = true;
      }
      final styles = widget.styleLoader == null
          ? await _loadStyles(snapshot?.mapTilerKey)
          : await widget.styleLoader!(snapshot?.mapTilerKey);
      final standard = styles.standard;
      final satellite = styles.satellite;
      if (snapshot?.mapTilerKey == null) {
        _satelliteUnavailable = true;
      } else if (satellite == null) {
        _satelliteUnavailable = true;
        dataFailed = true;
      }
      final firstCamera = _cameraPolicy.initialCamera(
        (snapshot?.people ?? const <PersonMapEntry>[])
            .map((person) => person.position)
            .whereType<LatLng>(),
        width: screenSize.width,
        height: screenSize.height - 170,
      );
      if (!mounted || generation != _loadGeneration) {
        standard.dispose();
        satellite?.dispose();
        return;
      }
      _standardStyle?.dispose();
      _satelliteStyle?.dispose();
      setState(() {
        _standardStyle = standard;
        _satelliteStyle = satellite;
        _people = snapshot?.people ?? const [];
        _places = snapshot?.places ?? const [];
        _mapTilerKey = snapshot?.mapTilerKey;
        _center = firstCamera.center;
        _zoom = firstCamera.zoom;
        _loading = false;
        _connectionFailed = dataFailed;
        _satelliteUnavailable =
            _satelliteUnavailable ||
            (snapshot?.mapTilerKey != null && satellite == null);
      });
      widget.onSatelliteUnavailable(_satelliteUnavailable);
      await _updates?.cancel();
      if (repository != null && !dataFailed) {
        _updates = repository
            .watchUpdates(onFailure: _onConnectionFailure)
            .listen(_applyUpdate, onError: (_) => _onConnectionFailure());
      }
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _connectionFailed = true;
      });
    }
  }

  Future<MapStyleSet> _loadStyles(String? mapTilerKey) async {
    final standard = await _readStyle(
      'https://tiles.openfreemap.org/styles/liberty',
    );
    vt.Style? satellite;
    if (mapTilerKey != null && mapTilerKey.isNotEmpty) {
      try {
        satellite = await _readStyle(
          'https://api.maptiler.com/maps/satellite-v4/style.json?key={key}',
          apiKey: mapTilerKey,
        );
      } on Object {
        satellite = null;
      }
    }
    return MapStyleSet(standard: standard, satellite: satellite);
  }

  Future<vt.Style> _readStyle(String uri, {String? apiKey}) async {
    final style = await vt.StyleReader(
      uri: uri,
      apiKey: apiKey,
      logger: const vt.Logger.noop(),
    ).read();
    return _stableCacheIdentity(style);
  }

  vt.Style _stableCacheIdentity(vt.Style source) {
    final providers = {
      for (final entry in source.providers.providers.entries)
        entry.key: StableTileCacheIdentity(entry.value),
    };
    final raster = {
      for (final entry in source.rasterSources.entries)
        entry.key: vt.RasterTileSource(
          provider: StableTileCacheIdentity(entry.value.provider),
          tileSize: entry.value.tileSize,
        ),
    };
    return vt.Style(
      theme: source.theme,
      providers: vt.TileProviders(providers),
      rasterSources: raster,
      sprites: source.sprites,
      center: source.center,
      zoom: source.zoom,
      name: source.name,
      attributions: source.attributions,
    );
  }

  void _applyUpdate(TraccarMapUpdate update) {
    if (!mounted) return;
    final byId = {for (final person in _people) person.deviceId: person};
    for (final device in update.devices) {
      final id = (device['id'] as num?)?.toInt();
      if (id == null) continue;
      final previous = byId[id];
      final position = previous?.position == null
          ? null
          : {
              'latitude': previous!.position!.latitude,
              'longitude': previous.position!.longitude,
              'fixTime': previous.fixTime?.toIso8601String(),
            };
      byId[id] = PersonMapEntry.fromTraccar(device: device, position: position);
    }
    for (final position in update.positions) {
      final id = (position['deviceId'] as num?)?.toInt();
      final person = id == null ? null : byId[id];
      if (person == null) continue;
      byId[id!] = PersonMapEntry.fromTraccar(
        device: {
          'id': person.deviceId,
          'name': person.displayName,
          'attributes': {
            if (person.imageRef != null) 'image': person.imageRef,
            if (person.batteryLevel != null)
              'batteryLevel': person.batteryLevel,
          },
        },
        position: position,
      );
    }
    setState(() {
      _people = byId.values.toList();
      _connectionFailed = false;
    });
  }

  void _onConnectionFailure() {
    if (!mounted) return;
    setState(() => _connectionFailed = true);
  }

  Future<void> _selectPerson(PersonMapEntry person) async {
    if (person.position == null || _selection.value.selectedPersonId != null) {
      return;
    }
    final before = _cameraPolicy.snapshot(_mapController.camera);
    _selection.select(person.personId, before);
    _mapController.move(
      person.position!,
      _mapController.camera.zoom.clamp(15, 18),
    );
    final description = _describePerson(person);
    if (!mounted) return;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => PersonDetailsSheet(
          person: person,
          locationDescription: description,
        ),
      );
    } finally {
      if (mounted) {
        final cameraSnapshot = _selection.restore();
        if (cameraSnapshot != null) {
          _mapController.moveAndRotate(
            cameraSnapshot.center,
            cameraSnapshot.zoom,
            cameraSnapshot.rotation,
          );
        }
        setState(() {});
      }
    }
  }

  Future<String> _describePerson(PersonMapEntry person) async {
    final point = person.position!;
    final coordinates =
        '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';
    if (widget.repository == null) return coordinates;
    try {
      final description = await LocationDescription(widget.repository!)
          .describe(
            person,
            _places,
            onServerFailure: () {
              if (mounted) setState(() => _connectionFailed = true);
            },
          );
      return description;
    } on Object {
      if (mounted) setState(() => _connectionFailed = true);
      return coordinates;
    }
  }

  Future<void> _retry() async {
    await _updates?.cancel();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final layerConfig = MapLayerConfig(
      mapTilerKey: _mapTilerKey,
      preference: MapAppearancePreference(
        satelliteThresholdZoom: widget.satelliteThresholdZoom,
      ),
    );
    final style = layerConfig.useSatellite(_zoom) && _satelliteStyle != null
        ? _satelliteStyle
        : _standardStyle;
    return Stack(
      children: [
        if (style != null)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              minZoom: 2,
              maxZoom: 20,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd && mounted) {
                  setState(() {
                    _zoom = event.camera.zoom;
                    _center = event.camera.center;
                  });
                }
              },
            ),
            children: [
              vt.VectorTileLayer(
                theme: style.theme,
                tileProviders: style.providers,
                rasterSources: style.rasterSources,
                sprites: style.sprites,
                diskCacheTtl: MapTileCachePolicy.freshness,
                diskCacheMaximumSizeInBytes:
                    MapTileCachePolicy.maximumSizeBytes,
                logger: vt.Logger.custom(onWarn: (_) => _onConnectionFailure()),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: [
                    for (final person in _people)
                      if (person.position case final point?)
                        Marker(
                          point: point,
                          width: 52,
                          height: 58,
                          alignment: Alignment.center,
                          child: PersonMarker(
                            key: ValueKey('person-${person.personId}'),
                            person: person,
                            onTap: () => unawaited(_selectPerson(person)),
                            imageLoader: widget.repository?.loadProfileImage,
                          ),
                        ),
                  ],
                  builder: (context, markers) =>
                      PersonClusterMarker(markers: markers),
                  maxClusterRadius: 56,
                  disableClusteringAtZoom: 19,
                  markerChildBehavior: true,
                  spiderfyCluster: true,
                  zoomToBoundsOnClick: false,
                ),
              ),
              MarkerLayer(
                markers: _placeLabels.build(
                  places: _places,
                  zoom: _zoom,
                  latitude: _center.latitude,
                ),
              ),
              RichAttributionWidget(
                attributions: [
                  for (final attribution in style.attributions)
                    TextSourceAttribution(attribution.text),
                  if (style.attributions.isEmpty)
                    const TextSourceAttribution('© OpenFreeMap'),
                  if (layerConfig.useSatellite(_zoom) &&
                      style.attributions.isEmpty)
                    const TextSourceAttribution('© MapTiler'),
                ],
              ),
            ],
          ),
        if (_connectionFailed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ServerConnectionBanner(
              message: 'Connection to server failed',
              actionLabel: 'Retry',
              onAction: () => unawaited(_retry()),
            ),
          ),
        if (_satelliteUnavailable &&
            !_connectionFailed &&
            !_satelliteNoticeDismissed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MaterialBanner(
              content: const Text('Satellite imagery is unavailable.'),
              actions: [
                TextButton(
                  onPressed: () =>
                      setState(() => _satelliteNoticeDismissed = true),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
        if (_people.every((person) => person.position == null) &&
            !_loading &&
            !_connectionFailed)
          const Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No people have reported a location yet.'),
              ),
            ),
          ),
      ],
    );
  }
}
