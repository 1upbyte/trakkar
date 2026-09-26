import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../places/auto_place_editor.dart';
import '../places/building_highlights.dart';
import '../places/building_lookup.dart';
import '../places/manual_place_editor.dart';
import '../../models/place_creation_draft.dart';
import '../../models/map_appearance_preference.dart';
import '../../models/map_view_state.dart';
import '../../models/person.dart';
import '../../models/saved_place.dart';
import '../../services/map/location_description.dart';
import '../../services/map/map_layer_config.dart';
import '../../services/traccar_data_repository.dart';
import '../../services/places/place_geometry.dart';
import '../../widgets/server_connection_banner.dart';
import '../people/people_list_state.dart';
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
    this.onPeopleStateChanged,
    this.onSavePlace,
    this.styleLoader,
    super.key,
  });

  final TraccarDataRepository? repository;
  final double satelliteThresholdZoom;
  final ValueChanged<bool> onSatelliteUnavailable;
  final void Function(PeopleListState state, List<SavedPlace> places)?
  onPeopleStateChanged;
  final Future<void> Function(
    String name,
    String area,
    SavedPlaceSource source,
  )?
  onSavePlace;
  final MapStyleLoader? styleLoader;

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _mapKey = GlobalKey();
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
  PlaceCreationMode? _placeCreationMode;
  BuildingLookup? _buildingLookup;
  BuildingLookupResult _buildingResult = const BuildingLookupResult();
  String? _selectedBuildingId;
  bool _reviewingBuilding = false;
  bool _savingPlace = false;
  bool _buildingLoading = false;
  List<LatLng> _manualPoints = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> selectPerson(String personId) async {
    for (final person in _people) {
      if (person.personId == personId) {
        await _selectPerson(person);
        return;
      }
    }
  }

  void updatePlaces(List<SavedPlace> places) {
    if (!mounted) return;
    setState(() => _places = List.of(places));
  }

  Future<void> startPlaceCreation(PlaceCreationMode mode) async {
    if (!mounted) return;
    setState(() {
      _placeCreationMode = mode;
      _manualPoints = const [];
      _buildingResult = const BuildingLookupResult();
      _selectedBuildingId = null;
      _reviewingBuilding = false;
      _buildingLoading = mode == PlaceCreationMode.auto;
    });
    if (mode == PlaceCreationMode.auto && _standardStyle != null) {
      await _searchBuildings();
    }
  }

  void cancelPlaceCreation() {
    if (!mounted) return;
    setState(() {
      _placeCreationMode = null;
      _manualPoints = const [];
      _buildingResult = const BuildingLookupResult();
      _selectedBuildingId = null;
      _reviewingBuilding = false;
      _savingPlace = false;
      _buildingLoading = false;
    });
  }

  Future<void> _searchBuildings() async {
    final style = _standardStyle;
    if (style == null) {
      setState(() {
        _buildingLoading = false;
        _buildingResult = const BuildingLookupResult(
          message: 'Building outlines are unavailable in this map style.',
        );
      });
      return;
    }
    final lookup = _buildingLookup ??= BuildingLookup(style: style);
    setState(() {
      _buildingLoading = true;
      _buildingResult = const BuildingLookupResult();
    });
    try {
      final camera = _mapController.camera;
      final result = await lookup.lookup(
        bounds: camera.visibleBounds,
        displayZoom: camera.zoom,
      );
      if (!mounted || _placeCreationMode != PlaceCreationMode.auto) return;
      setState(() {
        _buildingLoading = false;
        _buildingResult = result;
        if (_selectedBuildingId != null &&
            !result.candidates.any(
              (candidate) => candidate.id == _selectedBuildingId,
            )) {
          _selectedBuildingId = null;
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _buildingLoading = false;
        _buildingResult = const BuildingLookupResult(
          message: 'Building outlines could not be loaded.',
          hadTileFailure: true,
        );
      });
    }
  }

  void _selectBuilding(BuildingCandidate candidate) {
    setState(() => _selectedBuildingId = candidate.id);
  }

  void _onPlaceMapTap(LatLng point) {
    if (_placeCreationMode == PlaceCreationMode.manual) {
      setState(() => _manualPoints = [..._manualPoints, point]);
    } else if (_placeCreationMode == PlaceCreationMode.auto) {
      for (final candidate in _buildingResult.candidates) {
        if (candidate.contains(point)) {
          _selectBuilding(candidate);
          return;
        }
      }
    }
  }

  void _moveManualCorner(int index, Offset globalPosition) {
    final context = _mapKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final local = renderObject.globalToLocal(globalPosition);
    final point = _mapController.camera.screenOffsetToLatLng(local);
    if (!mounted || index >= _manualPoints.length) return;
    setState(() {
      final points = List<LatLng>.of(_manualPoints);
      points[index] = point;
      _manualPoints = points;
    });
  }

  Future<void> _savePlace(String name, List<LatLng> points) async {
    final callback = widget.onSavePlace;
    final error = PlaceGeometry.validationError(points);
    if (callback == null ||
        error != null ||
        name.trim().isEmpty ||
        _savingPlace) {
      return;
    }
    final source = _placeCreationMode == PlaceCreationMode.auto
        ? SavedPlaceSource.auto
        : SavedPlaceSource.manual;
    setState(() => _savingPlace = true);
    try {
      await callback(name.trim(), PlaceGeometry.toWktPolygon(points), source);
      if (!mounted) return;
      cancelPlaceCreation();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Place saved.')));
    } on Object {
      if (!mounted) return;
      setState(() => _savingPlace = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not save place. Try again.')),
        );
    }
  }

  Future<void> refresh() async {
    final repository = widget.repository;
    if (repository == null) return;
    try {
      final snapshot = await repository.loadMap();
      if (!mounted) return;
      setState(() {
        _people = snapshot.people;
        _places = snapshot.places;
        _connectionFailed = false;
      });
      widget.onPeopleStateChanged?.call(
        PeopleListState(people: _people),
        _places,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _connectionFailed = true);
      widget.onPeopleStateChanged?.call(
        PeopleListState(people: _people, hasError: true),
        _places,
      );
    }
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
    widget.onPeopleStateChanged?.call(
      PeopleListState(people: _people, isLoading: true),
      _places,
    );
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
      _buildingLookup = null;
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
      widget.onPeopleStateChanged?.call(
        PeopleListState(people: _people, hasError: dataFailed),
        _places,
      );
      if (_placeCreationMode == PlaceCreationMode.auto) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _placeCreationMode == PlaceCreationMode.auto) {
            unawaited(_searchBuildings());
          }
        });
      }
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
      widget.onPeopleStateChanged?.call(
        PeopleListState(people: _people, hasError: true),
        _places,
      );
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
              if (previous.address != null) 'address': previous.address,
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
    widget.onPeopleStateChanged?.call(
      PeopleListState(people: _people),
      _places,
    );
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
            key: _mapKey,
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
                  if (_placeCreationMode == PlaceCreationMode.auto) {
                    unawaited(_searchBuildings());
                  }
                }
              },
              onTap: (_, point) => _onPlaceMapTap(point),
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
              if (_placeCreationMode == PlaceCreationMode.auto)
                PolygonLayer(
                  polygons: BuildingHighlights.build(
                    candidates: _buildingResult.candidates,
                    selectedId: _selectedBuildingId,
                  ),
                ),
              if (_placeCreationMode == PlaceCreationMode.manual &&
                  _manualPoints.length >= 3)
                PolygonLayer(
                  polygons: [BuildingHighlights.draft(_manualPoints)],
                ),
              if (_placeCreationMode == PlaceCreationMode.manual)
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < _manualPoints.length; i++)
                      Marker(
                        point: _manualPoints[i],
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onPanUpdate: (details) =>
                              _moveManualCorner(i, details.globalPosition),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                  ],
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
        if (_placeCreationMode == PlaceCreationMode.auto)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AutoPlaceEditor(
              candidates: _buildingResult.candidates,
              selectedId: _selectedBuildingId,
              isLoading: _buildingLoading,
              isReviewing: _reviewingBuilding,
              isSaving: _savingPlace,
              message:
                  _buildingResult.message ??
                  (_zoom < 16
                      ? 'Zoom in to level 16 to search for buildings.'
                      : null),
              attribution: (_standardStyle?.attributions ?? const [])
                  .map((source) => source.text)
                  .join(' · '),
              onSelect: _selectBuilding,
              onReview: () => setState(() => _reviewingBuilding = true),
              onSearchArea: () => unawaited(_searchBuildings()),
              onUseManual: () =>
                  unawaited(startPlaceCreation(PlaceCreationMode.manual)),
              onCancel: cancelPlaceCreation,
              onSave: (name) {
                final selected = _buildingResult.candidates
                    .where((candidate) => candidate.id == _selectedBuildingId)
                    .firstOrNull;
                return selected == null
                    ? Future<void>.value()
                    : _savePlace(name, selected.points);
              },
            ),
          ),
        if (_placeCreationMode == PlaceCreationMode.manual)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ManualPlaceEditor(
              points: _manualPoints,
              validationError: PlaceGeometry.validationError(_manualPoints),
              isSaving: _savingPlace,
              onRemoveLast: () => setState(() {
                if (_manualPoints.isNotEmpty) {
                  _manualPoints = _manualPoints.sublist(
                    0,
                    _manualPoints.length - 1,
                  );
                }
              }),
              onCancel: cancelPlaceCreation,
              onSave: (name) => _savePlace(name, _manualPoints),
            ),
          ),
      ],
    );
  }
}
