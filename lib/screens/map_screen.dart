import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/location_label.dart';
import '../widgets/building_highlights.dart';
import '../models/named_place.dart';
import '../services/building_lookup.dart';
import '../services/named_place_store.dart';
import 'places_screen.dart';
import '../models/traccar_device.dart';
import '../models/traccar_position.dart';

const _streetStyleUri = 'https://tiles.openfreemap.org/styles/positron';
const _darkStreetStyleUri = 'https://tiles.openfreemap.org/styles/dark';
const _minMapZoom = 2.0;
const _maxMapZoom = 21.0;
const _personFocusZoom = 18.0;

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.visible,
    this.placeCreationRequest = 0,
    this.autoPlace = false,
    super.key,
  });

  final bool visible;
  final int placeCreationRequest;
  final bool autoPlace;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _cameraAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  VoidCallback? _cameraTick;
  bool? _requestedDarkMap;
  int _styleRequest = 0;
  vt.Style? _baseMapStyle;
  Object? _baseMapError;
  bool _fittedInitialPositions = false;
  double _zoom = 12;
  bool _drawingPlace = false;
  bool _autoBuilding = false;
  bool _buildingBusy = false;
  int _buildingSession = 0;
  final _buildingLookup = BuildingLookup();
  final _buildingHits = ValueNotifier<LayerHitResult<String>?>(null);
  List<BuildingFootprint> _availableBuildings = [];
  Timer? _buildingRefresh;
  String? _buildingError;
  final List<BuildingFootprint> _selectedBuildings = [];
  double _rotation = 0;
  final List<LatLng> _draftBoundary = <LatLng>[];
  PersistentBottomSheetController? _personSheetController;

  late final NetworkTileProvider _satelliteTileProvider = NetworkTileProvider(
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: 512 * 1024 * 1024,
      overrideFreshAge: const Duration(days: 90),
      tileKeyGenerator: _satelliteCacheKey,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final darkMap = context.watch<AppState>().darkMap;
    if (_requestedDarkMap != darkMap) {
      _requestedDarkMap = darkMap;
      unawaited(_loadBaseMap());
    }
    if (MediaQuery.disableAnimationsOf(context)) _cameraAnimation.stop();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.placeCreationRequest != oldWidget.placeCreationRequest) {
      _startDrawingPlace(auto: widget.autoPlace);
    }
    if (oldWidget.visible && !widget.visible) {
      _buildingRefresh?.cancel();
      _buildingSession++;
      _buildingBusy = false;
      _cameraAnimation.stop();
      _personSheetController?.close();
      if (_drawingPlace) {
        setState(() {
          _drawingPlace = false;
          _draftBoundary.clear();
        });
      }
    }
  }

  Future<void> _loadBaseMap() async {
    final request = ++_styleRequest;
    try {
      final style = await vt.StyleReader(
        uri: _requestedDarkMap == true ? _darkStreetStyleUri : _streetStyleUri,
      ).read();
      if (!mounted || request != _styleRequest) {
        style.dispose();
        return;
      }
      final previous = _baseMapStyle;
      setState(() {
        _baseMapStyle = style;
        _baseMapError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous?.dispose();
        if (mounted && _drawingPlace && _autoBuilding) _scheduleBuildings();
      });
    } on Object catch (error) {
      if (mounted && request == _styleRequest) {
        setState(() => _baseMapError = error);
      }
    }
  }

  @override
  void dispose() {
    _personSheetController?.close();
    _buildingRefresh?.cancel();
    _buildingHits.dispose();
    _cameraAnimation.dispose();
    _mapController.dispose();
    _baseMapStyle?.dispose();
    super.dispose();
  }

  void _animateCamera(LatLng target, double zoom, {double? rotation}) {
    _cameraAnimation.stop();
    if (_cameraTick != null) _cameraAnimation.removeListener(_cameraTick!);
    if (MediaQuery.disableAnimationsOf(context) || !widget.visible) {
      _mapController.move(target, zoom);
      if (rotation != null) _mapController.rotate(rotation);
      return;
    }
    final camera = _mapController.camera;
    final rotationDelta = rotation == null
        ? 0.0
        : (rotation - camera.rotation + 180) % 360 - 180;
    final start = camera.projectAtZoom(camera.center, 0);
    // Choose the nearest world copy when crossing the date line.
    final longitude =
        camera.center.longitude +
        ((target.longitude - camera.center.longitude + 180) % 360 - 180);
    final end = camera.projectAtZoom(LatLng(target.latitude, longitude), 0);
    _cameraTick = () {
      final t = Curves.easeInOutCubic.transform(_cameraAnimation.value);
      final point = camera.unprojectAtZoom(Offset.lerp(start, end, t)!, 0);
      if (rotation != null) {
        _mapController.rotate(camera.rotation + rotationDelta * t);
      }
      _mapController.move(
        LatLng(point.latitude, (point.longitude + 180) % 360 - 180),
        camera.zoom + (zoom - camera.zoom) * t,
      );
    };
    _cameraAnimation.addListener(_cameraTick!);
    _cameraAnimation.forward(from: 0);
  }

  void _fitPositions(AppState state) {
    final points = state.positions.values
        .map((position) => LatLng(position.latitude, position.longitude))
        .toList(growable: false);
    if (points.isEmpty) return;
    if (points.length == 1) {
      _animateCamera(points.first, 15);
      return;
    }
    final fitted = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(48, 120, 48, 180),
    ).fit(_mapController.camera);
    _animateCamera(fitted.center, fitted.zoom.clamp(_minMapZoom, _maxMapZoom));
  }

  Future<bool> _addPlace(LatLng point) async {
    final name = TextEditingController();
    final radius = TextEditingController(text: '150');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this place'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Place name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius in meters',
                helperText: 'Positions inside this area use the place name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    var saved = false;
    if ((result ?? false) && name.text.trim().isNotEmpty && mounted) {
      try {
        await context.read<AppState>().addNamedPlace(
          name: name.text,
          latitude: point.latitude,
          longitude: point.longitude,
          radiusMeters: double.tryParse(radius.text) ?? 150,
        );
        saved = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${name.text.trim()} is now shared with the account.',
              ),
            ),
          );
        }
      } on Object {
        if (mounted) {
          final message =
              context.read<AppState>().lastError ??
              'The place could not be saved.';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
    name.dispose();
    radius.dispose();
    return saved;
  }

  void _startDrawingPlace({bool auto = false}) {
    _personSheetController?.close();
    setState(() {
      _buildingRefresh?.cancel();
      _buildingSession++;
      _buildingBusy = false;
      _buildingError = null;
      _availableBuildings = [];
      _autoBuilding = auto;
      _selectedBuildings.clear();
      _drawingPlace = true;
      _draftBoundary.clear();
    });
    if (auto) {
      if (_zoom < 16) {
        _animateCamera(_mapController.camera.center, 17);
      }
      _scheduleBuildings();
    }
  }

  void _cancelDrawingPlace() {
    setState(() {
      _buildingRefresh?.cancel();
      _buildingSession++;
      _buildingBusy = false;
      _selectedBuildings.clear();
      _drawingPlace = false;
      _draftBoundary.clear();
    });
  }

  Future<void> _finishDrawingPlace() async {
    if (_draftBoundary.length < 3) return;
    final names = _selectedBuildings
        .map((building) => building.name)
        .where((name) => name.isNotEmpty)
        .toSet();
    final name = TextEditingController(text: names.join(' / '));
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this place'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Place name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final cleanName = name.text.trim();
    name.dispose();
    if (!(save ?? false) || cleanName.isEmpty || !mounted) return;

    final boundary = List<LatLng>.unmodifiable(_draftBoundary);
    final latitude =
        boundary.fold<double>(0, (total, point) => total + point.latitude) /
        boundary.length;
    final longitude =
        boundary.fold<double>(0, (total, point) => total + point.longitude) /
        boundary.length;
    try {
      await context.read<AppState>().addNamedPlace(
        name: cleanName,
        latitude: latitude,
        longitude: longitude,
        boundary: boundary,
      );
      if (!mounted) return;
      _cancelDrawingPlace();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$cleanName is now shared with the account.')),
      );
    } on Object {
      if (!mounted) return;
      final message =
          context.read<AppState>().lastError ?? 'The place could not be saved.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _updateBuildingBoundary() {
    _draftBoundary
      ..clear()
      ..addAll(buildingBoundary(_selectedBuildings));
  }

  void _handleMapTap(LatLng point) {
    if (_drawingPlace) {
      if (_autoBuilding) {
        _selectBuilding(point);
      } else {
        setState(() => _draftBoundary.add(point));
      }
      return;
    }
    final place = NamedPlaceStore.nearest(
      context.read<AppState>().namedPlaces,
      point.latitude,
      point.longitude,
    );
    if (place != null) _showPlaceSheet(place);
  }

  void _scheduleBuildings() {
    if (!_drawingPlace || !_autoBuilding || !widget.visible) return;
    _buildingRefresh?.cancel();
    // Invalidate any request for the previous viewport.
    final session = ++_buildingSession;
    _buildingRefresh = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadSelectableBuildings(session));
    });
  }

  Future<void> _loadSelectableBuildings(int session) async {
    if (!mounted || session != _buildingSession) return;
    if (_zoom < 16) {
      setState(() {
        _buildingBusy = false;
        _availableBuildings = [];
        _buildingError = 'Zoom in to see selectable buildings.';
      });
      return;
    }
    final style = _baseMapStyle;
    final sources = style?.theme.referencedSourceLayers.entries.where(
      (entry) => entry.value.contains('building'),
    );
    final source = sources?.firstOrNull?.key;
    final provider = source == null ? null : style?.providers[source];
    if (provider == null) {
      setState(() {
        _buildingBusy = false;
        _buildingError =
            'Waiting for the map. Retry if outlines do not appear.';
      });
      return;
    }
    setState(() {
      _buildingBusy = true;
      _buildingError = null;
    });
    try {
      final buildings = await _buildingLookup.inBounds(
        provider,
        _mapController.camera.visibleBounds,
      );
      if (!mounted || session != _buildingSession) return;
      setState(() {
        _availableBuildings = buildings;
        if (buildings.isEmpty) {
          _buildingError =
              'No mapped buildings here. Move the map or draw manually.';
        }
      });
    } on Object catch (error) {
      if (!mounted || session != _buildingSession) return;
      setState(() {
        _buildingError = error is FormatException
            ? error.message
            : 'Could not load outlines. Tap Retry.';
      });
    } finally {
      if (mounted && session == _buildingSession) {
        setState(() => _buildingBusy = false);
      }
    }
  }

  void _selectBuilding(LatLng point) {
    final candidates = <String, BuildingFootprint>{
      for (final b in _availableBuildings) b.id: b,
      for (final b in _selectedBuildings) b.id: b,
    };
    final hitId = _buildingHits.value?.hitValues.firstOrNull;
    final hits = candidates.values.where((b) => b.contains(point)).toList()
      ..sort(
        (a, b) => polygonArea(a.boundary).compareTo(polygonArea(b.boundary)),
      );
    final building = candidates[hitId] ?? hits.firstOrNull;
    if (building == null) return;
    setState(() {
      final selected = _selectedBuildings.indexWhere(
        (b) => b.id == building.id,
      );
      if (selected >= 0) {
        _selectedBuildings.removeAt(selected);
      } else {
        _selectedBuildings.add(building);
      }
      _updateBuildingBoundary();
    });
  }

  void _showPlaceSheet(NamedPlace place) {
    _personSheetController?.close();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: PlacesScreen(selectedPlaceId: place.id),
      ),
    );
  }

  void _showPersonSheet(
    TraccarDevice device,
    TraccarPosition position,
    AppState state,
  ) {
    final address = state
        .reverseGeocode(position)
        .catchError((Object _) => locationFallback(position));
    _personSheetController?.close();
    late final PersistentBottomSheetController controller;
    controller = showBottomSheet(
      context: context,
      enableDrag: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.28,
        minChildSize: 0.20,
        maxChildSize: 0.72,
        expand: false,
        builder: (context, scrollController) => _PersonSheet(
          device: device,
          position: position,
          imageBytes: state.deviceImages[device.id],
          address: address,
          arrival: state.arrivalSummary(position),
          scrollController: scrollController,
          onNamePlace: () =>
              _addPlace(LatLng(position.latitude, position.longitude)),
        ),
      ),
    );
    setState(() => _personSheetController = controller);
    unawaited(
      controller.closed.whenComplete(() {
        if (identical(_personSheetController, controller)) {
          if (mounted) setState(() => _personSheetController = null);
        }
      }),
    );
  }

  void _focusPerson(
    TraccarDevice device,
    TraccarPosition position,
    AppState state,
  ) {
    final point = LatLng(position.latitude, position.longitude);
    _animateCamera(point, math.max(_zoom, _personFocusZoom));
    _showPersonSheet(device, position, state);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devicesById = <int, TraccarDevice>{
      for (final device in state.devices) device.id: device,
    };
    final ownDevice = state.ownDevice;
    final currentDevicePosition = ownDevice == null
        ? null
        : state.positions[ownDevice.id];
    final initialPosition =
        currentDevicePosition ?? state.positions.values.firstOrNull;
    if (!_fittedInitialPositions && state.positions.isNotEmpty) {
      _fittedInitialPositions = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitPositions(context.read<AppState>());
      });
    }
    final baseMapStyle = _baseMapStyle;
    final showSatellite =
        state.satelliteAtZoom(_zoom) && state.mapTilerApiKey.isNotEmpty;
    final satelliteMissingKey =
        state.satelliteAtZoom(_zoom) && state.mapTilerApiKey.isEmpty;
    final attribution = baseMapStyle?.attributions
        .map((item) => item.text)
        .where((text) => text.isNotEmpty)
        .join(' · ');
    final placeColor = Theme.of(context).colorScheme.tertiary;

    return PopScope(
      canPop: _personSheetController == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _personSheetController?.close();
      },
      child: Stack(
        children: [
          Listener(
            onPointerDown: (_) => _cameraAnimation.stop(),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialPosition == null
                    ? const LatLng(20, 0)
                    : LatLng(
                        initialPosition.latitude,
                        initialPosition.longitude,
                      ),
                backgroundColor: state.darkMap
                    ? const Color(0xFF171A21)
                    : const Color(0xFFE9ECE8),
                initialZoom: initialPosition == null ? 2.5 : 12,
                minZoom: _minMapZoom,
                maxZoom: _maxMapZoom,
                onTap: (_, point) => _handleMapTap(point),
                onPositionChanged: (camera, _) {
                  final wasSatelliteZoom = state.satelliteAtZoom(_zoom);
                  final isSatelliteZoom = state.satelliteAtZoom(camera.zoom);
                  final zoomChanged = _zoom != camera.zoom;
                  _zoom = camera.zoom;
                  _scheduleBuildings();
                  if (zoomChanged ||
                      wasSatelliteZoom != isSatelliteZoom ||
                      _rotation != camera.rotation) {
                    setState(() => _rotation = camera.rotation);
                  }
                },
                onLongPress: _drawingPlace
                    ? null
                    : (_, point) => unawaited(_addPlace(point)),
              ),
              children: [
                if (baseMapStyle != null)
                  vt.VectorTileLayer(
                    theme: baseMapStyle.theme,
                    tileProviders: baseMapStyle.providers,
                    rasterSources: baseMapStyle.rasterSources,
                    sprites: baseMapStyle.sprites,
                    showLabels: true,
                    concurrency: 2,
                    diskCacheMaximumSizeInBytes: 40 * 1024 * 1024,
                  )
                else
                  ColoredBox(
                    color: state.darkMap
                        ? const Color(0xFF171A21)
                        : const Color(0xFFE9ECE8),
                    child: const SizedBox.expand(),
                  ),
                // Keep this layer mounted so its long-lived HTTP client remains
                // reusable as the user crosses the satellite zoom threshold.
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/satellite-v4/'
                      '{z}/{x}/{y}@2x.jpg?key=${state.mapTilerApiKey}',
                  userAgentPackageName: 'com.oneupbyte.trakkar',
                  tileProvider: _satelliteTileProvider,
                  minZoom: state.mapTilerApiKey.isEmpty
                      ? _maxMapZoom + 1
                      : state.satelliteAlways
                      ? _minMapZoom
                      : state.satelliteAutoAtStreetZoom
                      ? state.satelliteZoom
                      : _maxMapZoom + 1,
                  tileDimension: 512,
                  zoomOffset: -1,
                  maxNativeZoom: 21,
                  maxZoom: _maxMapZoom,
                ),
                PolygonLayer(
                  polygons: <Polygon>[
                    if (_draftBoundary.length >= 3)
                      Polygon(
                        points: _draftBoundary,
                        color: placeColor.withValues(alpha: 0.22),
                        borderColor: placeColor,
                        borderStrokeWidth: 3,
                      ),
                  ],
                ),
                if (_draftBoundary.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _draftBoundary,
                        color: placeColor,
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                if (_draftBoundary.isNotEmpty)
                  CircleLayer(
                    circles: _draftBoundary
                        .map(
                          (point) => CircleMarker(
                            point: point,
                            radius: 6,
                            color: Theme.of(context).colorScheme.surface,
                            borderColor: placeColor,
                            borderStrokeWidth: 3,
                          ),
                        )
                        .toList(growable: false),
                  ),
                if (_drawingPlace && _autoBuilding)
                  BuildingHighlights(
                    buildings: {
                      for (final b in _availableBuildings) b.id: b,
                      for (final b in _selectedBuildings) b.id: b,
                    }.values.toList(),
                    selectedIds: _selectedBuildings.map((b) => b.id).toSet(),
                    hitNotifier: _buildingHits,
                  ),
                MarkerLayer(
                  markers: state.namedPlaces
                      .where((place) => placeLabelVisible(place, _zoom))
                      .map(
                        (place) => Marker(
                          point: LatLng(place.latitude, place.longitude),
                          width: 160,
                          height: 44,
                          rotate: true,
                          child: GestureDetector(
                            onTap: () => _showPlaceSheet(place),
                            child: Center(
                              child: Text(
                                place.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: state.darkMap
                                      ? Colors.white
                                      : const Color(0xFF454B50),
                                  shadows: [
                                    Shadow(
                                      color: state.darkMap
                                          ? Colors.black
                                          : Colors.white,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    rotate: true,
                    maxClusterRadius: 60,
                    maxZoom: _maxMapZoom,
                    disableClusteringAtZoom: 22,
                    zoomToBoundsOnClick: false,
                    spiderfyCluster: true,
                    spiderfyCircleRadius: 72,
                    showPolygon: false,
                    markerChildBehavior: true,
                    size: const Size(72, 54),
                    markers: state.positions.entries
                        .map((entry) {
                          final device = devicesById[entry.key];
                          final position = entry.value;
                          return Marker(
                            key: ValueKey(entry.key),
                            point: LatLng(
                              position.latitude,
                              position.longitude,
                            ),
                            width: 126,
                            height: 64,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: device == null
                                  ? null
                                  : () => _focusPerson(device, position, state),
                              child: _AvatarMarker(
                                name: device?.name ?? 'Unknown',
                                online: device?.status == 'online',
                                driving: state.isDriving(position),
                                position: position,
                                imageBytes: device == null
                                    ? null
                                    : state.deviceImages[device.id],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                    builder: (context, markers) {
                      final people = <_ClusterPerson>[];
                      for (final marker in markers) {
                        final key = marker.key;
                        if (key is! ValueKey<int>) continue;
                        final device = devicesById[key.value];
                        people.add(
                          _ClusterPerson(
                            name: device?.name ?? 'Unknown',
                            imageBytes: state.deviceImages[key.value],
                          ),
                        );
                      }
                      return _ClusterMarker(people: people);
                    },
                  ),
                ),
                RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution(
                      showSatellite
                          ? '© MapTiler · © OpenStreetMap contributors'
                          : attribution?.isNotEmpty ?? false
                          ? attribution!
                          : 'OpenFreeMap · OpenMapTiles · OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_baseMapError != null || satelliteMissingKey)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 72,
              left: 16,
              right: 16,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(
                    satelliteMissingKey
                        ? 'Satellite imagery is not configured'
                        : 'Map style unavailable',
                  ),
                  subtitle: Text(
                    satelliteMissingKey
                        ? 'Add trakkarMapTilerKey to the Traccar server attributes.'
                        : 'Check the connection and retry. Locations are still live.',
                  ),
                  trailing: satelliteMissingKey
                      ? null
                      : TextButton(
                          onPressed: () {
                            setState(() => _baseMapError = null);
                            unawaited(_loadBaseMap());
                          },
                          child: const Text('Retry'),
                        ),
                ),
              ),
            ),
          if (!_drawingPlace)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 14,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'refreshMap',
                    onPressed: state.refresh,
                    tooltip: 'Refresh positions',
                    child: const Icon(Icons.refresh),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'fitMap',
                    onPressed: () => _fitPositions(state),
                    tooltip: 'Show everyone',
                    child: const Icon(Icons.zoom_out_map_rounded),
                  ),
                ],
              ),
            ),
          Positioned(
            right: 16,
            bottom: _drawingPlace ? 190 : 32,
            child: FloatingActionButton.small(
              heroTag: 'compass',
              tooltip: 'Point north',
              onPressed: () => _animateCamera(
                _mapController.camera.center,
                _zoom,
                rotation: 0,
              ),
              child: Transform.rotate(
                angle: _rotation * math.pi / 180,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'N',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Icon(
                      Icons.north_rounded,
                      size: 24,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_drawingPlace)
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _autoBuilding
                            ? (_buildingError ??
                                  (_buildingBusy
                                      ? 'Loading selectable buildings…'
                                      : 'Tap highlighted buildings to add or remove them'))
                            : _draftBoundary.length < 3
                            ? 'Tap at least 3 corners of the place'
                            : 'Tap to add more corners, or finish the shape',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_autoBuilding) ...[
                        const SizedBox(height: 6),
                        const Text('Blue: selectable · Green: selected'),
                        if (_buildingError != null)
                          TextButton(
                            onPressed: () {
                              if (_baseMapStyle == null) {
                                unawaited(_loadBaseMap());
                              }
                              _scheduleBuildings();
                            },
                            child: const Text('Retry'),
                          ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _autoBuilding
                            ? '${_selectedBuildings.length} buildings selected · © OpenStreetMap contributors'
                            : '${_draftBoundary.length} corners added',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _cancelDrawingPlace,
                            child: const Text('Cancel'),
                          ),
                          IconButton(
                            tooltip: _autoBuilding
                                ? 'Undo last building'
                                : 'Undo last corner',
                            onPressed: _buildingBusy || _draftBoundary.isEmpty
                                ? null
                                : () => setState(() {
                                    if (_autoBuilding) {
                                      _selectedBuildings.removeLast();
                                      _updateBuildingBoundary();
                                    } else {
                                      _draftBoundary.removeLast();
                                    }
                                  }),
                            icon: const Icon(Icons.undo_rounded),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed:
                                _buildingBusy || _draftBoundary.length < 3
                                ? null
                                : () => unawaited(_finishDrawingPlace()),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Finish'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.positions.isEmpty)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_pin_circle_outlined, size: 38),
                      const SizedBox(height: 10),
                      Text(
                        'Waiting for locations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('New positions will appear here live.'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarMarker extends StatelessWidget {
  const _AvatarMarker({
    required this.name,
    required this.online,
    required this.driving,
    required this.position,
    required this.imageBytes,
  });

  final String name;
  final bool online;
  final bool driving;
  final TraccarPosition position;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final showMotion = driving || position.isMoving;
    final speedMph = position.speedMph;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 35,
          top: 4,
          width: 56,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
              image: imageBytes == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(imageBytes!),
                      fit: BoxFit.cover,
                    ),
            ),
            alignment: Alignment.center,
            child: imageBytes == null
                ? Text(
                    _initial(name),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
        ),
        if (showMotion)
          Positioned(
            left: 86,
            top: 5,
            child: Semantics(
              label:
                  '${driving ? 'Driving' : 'Walking'}, '
                  '${speedMph.round()} miles per hour',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      driving ? '🚗' : '🚶',
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      '${speedMph.round()} mph',
                      style:
                          const TextStyle(
                            fontSize: 8,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ).copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 78,
          bottom: 3,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF36A269) : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.people});

  final List<_ClusterPerson> people;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = people.take(3).toList(growable: false);
    final totalWidth = 38.0 + math.max(0, visible.length - 1) * 17;
    final start = (72 - totalWidth) / 2;
    return Semantics(
      button: true,
      label: '${people.length} people nearby. Tap to spread them out.',
      child: SizedBox(
        width: 72,
        height: 54,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < visible.length; index++)
              Positioned(
                left: start + index * 17,
                top: 5,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primaryContainer,
                    border: Border.all(color: colors.surface, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x44000000), blurRadius: 5),
                    ],
                    image: visible[index].imageBytes == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(visible[index].imageBytes!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: visible[index].imageBytes == null
                      ? Text(
                          _initial(visible[index].name),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
              ),
            if (people.length > visible.length)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: Text(
                    '+${people.length - visible.length}',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClusterPerson {
  const _ClusterPerson({required this.name, required this.imageBytes});

  final String name;
  final Uint8List? imageBytes;
}

class _PersonSheet extends StatelessWidget {
  const _PersonSheet({
    required this.device,
    required this.position,
    required this.imageBytes,
    required this.address,
    required this.arrival,
    required this.scrollController,
    required this.onNamePlace,
  });

  final TraccarDevice device;
  final TraccarPosition position;
  final Uint8List? imageBytes;
  final Future<String> address;
  final Future<String> arrival;
  final ScrollController scrollController;
  final Future<bool> Function() onNamePlace;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 38,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: imageBytes == null
                  ? Text(
                      _initial(device.name),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : ClipOval(
                      child: Image.memory(
                        imageBytes!,
                        width: 76,
                        height: 76,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              device.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            LocationLabel(position: position, address: address, showAge: false),
            FutureBuilder<String>(
              future: arrival,
              builder: (context, snapshot) =>
                  Text(snapshot.data ?? 'Here since: checking arrival…'),
            ),
            const SizedBox(height: 8),
            Text(
              _positionSummary(position),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final saved = await onNamePlace();
                  if (saved && context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Give this place a friendly name'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _positionSummary(TraccarPosition position) {
    final time = position.fixTime?.toLocal();
    final clock = time == null
        ? 'Time unknown'
        : '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';
    return '$clock  •  ${position.speedMph.round()} mph';
  }
}

String _initial(String name) {
  final clean = name.trim();
  return clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
}

String _satelliteCacheKey(String url) {
  try {
    final uri = Uri.parse(url);
    final query = Map<String, String>.from(uri.queryParameters)..remove('key');
    return BuiltInMapCachingProvider.uuidTileKeyGenerator(
      uri.replace(queryParameters: query.isEmpty ? null : query).toString(),
    );
  } on FormatException {
    return BuiltInMapCachingProvider.uuidTileKeyGenerator(url);
  }
}

/// Hide names when the place occupies less than 80 logical pixels on the map.
bool placeLabelVisible(NamedPlace place, double zoom) {
  final metersPerPixel =
      156543.03392 *
      math.cos(place.latitude * math.pi / 180).abs() /
      math.pow(2, zoom);
  double diameter = place.radiusMeters * 2;
  if (place.isPolygon) {
    final bounds = LatLngBounds.fromPoints(place.boundary);
    const distance = Distance();
    final width = distance.as(
      LengthUnit.Meter,
      LatLng(place.latitude, bounds.west),
      LatLng(place.latitude, bounds.east),
    );
    final height = distance.as(
      LengthUnit.Meter,
      LatLng(bounds.south, place.longitude),
      LatLng(bounds.north, place.longitude),
    );
    diameter = math.sqrt(width * height);
  }
  return diameter / metersPerPixel >= 80;
}
