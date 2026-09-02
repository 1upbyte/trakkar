import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/map_style_option.dart';
import '../models/traccar_device.dart';
import '../models/traccar_position.dart';
import 'map_marker_bitmaps.dart';

/// Zoom levels that switch the base map to imagery, Life360 style. The gap
/// between them prevents flicker while pinching around the threshold.
const _imageryEnterZoom = 15.5;
const _imageryExitZoom = 14.5;

class MapScreen extends StatefulWidget {
  const MapScreen({required this.onPeopleTap, super.key});

  final VoidCallback onPeopleTap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController _mapController = MapController();
  gm.GoogleMapController? _googleController;
  final _markerBitmaps = MarkerBitmapCache();
  vt.Style? _baseMapStyle;
  Object? _baseMapError;
  MapStyleOption? _requestedMapStyle;
  int _styleLoadGeneration = 0;
  bool _centeredOnCurrentDevice = false;
  bool _zoomedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final requested = context.watch<AppState>().mapStyle;
    if (_requestedMapStyle != requested) {
      final previous = _requestedMapStyle;
      _requestedMapStyle = requested;
      if (previous != null && previous.isGoogle != requested.isGoogle) {
        // A MapController binds to one FlutterMap instance. Swapping the
        // rendering stack needs a fresh one; the Google controller is
        // recreated by onMapCreated.
        _mapController.dispose();
        _mapController = MapController();
        _googleController = null;
      }
      unawaited(_loadBaseMap(requested));
    }
  }

  /// Tracks whether the camera is close enough to switch to imagery.
  void _onZoomChanged(double zoom) {
    final zoomedIn = _zoomedIn
        ? zoom >= _imageryExitZoom
        : zoom >= _imageryEnterZoom;
    if (zoomedIn != _zoomedIn && mounted) {
      setState(() => _zoomedIn = zoomedIn);
    }
  }

  void _moveTo(LatLng point, double zoom) {
    if (_requestedMapStyle?.isGoogle ?? false) {
      _googleController?.moveCamera(
        gm.CameraUpdate.newLatLngZoom(
          gm.LatLng(point.latitude, point.longitude),
          zoom,
        ),
      );
    } else {
      _mapController.move(point, zoom);
    }
  }

  Future<void> _loadBaseMap(MapStyleOption requested) async {
    final generation = ++_styleLoadGeneration;
    if (requested.openFreeMapStyleUri == null) {
      _baseMapStyle?.dispose();
      _baseMapStyle = null;
      _baseMapError = null;
      if (mounted) setState(() {});
      return;
    }
    try {
      final style = await vt.StyleReader(uri: requested.openFreeMapStyleUri!)
          .read();
      if (!mounted || generation != _styleLoadGeneration) {
        style.dispose();
        return;
      }
      final previous = _baseMapStyle;
      setState(() {
        _baseMapStyle = style;
        _baseMapError = null;
      });
      previous?.dispose();
    } on Object catch (error) {
      if (mounted && generation == _styleLoadGeneration) {
        setState(() => _baseMapError = error);
      }
    }
  }

  @override
  void dispose() {
    _baseMapStyle?.dispose();
    _mapController.dispose();
    _markerBitmaps.dispose();
    super.dispose();
  }

  void _fitPositions(AppState state) {
    final points = state.positions.values
        .map((position) => LatLng(position.latitude, position.longitude))
        .toList(growable: false);
    if (points.isEmpty) return;
    if (points.length == 1) {
      _moveTo(points.first, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    if (state.mapStyle.isGoogle) {
      _googleController?.animateCamera(
        gm.CameraUpdate.newLatLngBounds(
          gm.LatLngBounds(
            southwest: gm.LatLng(bounds.south, bounds.west),
            northeast: gm.LatLng(bounds.north, bounds.east),
          ),
          96,
        ),
      );
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 180),
      ),
    );
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

  Future<void> _showPersonSheet(
    TraccarDevice device,
    TraccarPosition position,
    AppState state,
  ) async {
    final address = state.reverseGeocode(position);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _PersonSheet(
        device: device,
        position: position,
        imageBytes: state.deviceImages[device.id],
        address: address,
        onNamePlace: () =>
            _addPlace(LatLng(position.latitude, position.longitude)),
      ),
    );
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
    if (!_centeredOnCurrentDevice && currentDevicePosition != null) {
      _centeredOnCurrentDevice = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveTo(
          LatLng(
            currentDevicePosition.latitude,
            currentDevicePosition.longitude,
          ),
          12,
        );
      });
    }
    final selectedMapStyle = state.mapStyle;
    final googleMissingKey = selectedMapStyle.isGoogle && !state.googleMapsReady;
    final satelliteMissingKey =
        selectedMapStyle.isSatellite && state.mapApiKeys.mapTiler.isEmpty;
    final initialCenter = initialPosition == null
        ? const LatLng(20, 0)
        : LatLng(initialPosition.latitude, initialPosition.longitude);
    final initialZoom = initialPosition == null ? 2.5 : 12.0;

    return Stack(
      children: [
        if (selectedMapStyle.isGoogle && !googleMissingKey)
          _buildGoogleMap(
            state,
            devicesById,
            initialCenter: initialCenter,
            initialZoom: initialZoom,
          )
        else if (selectedMapStyle.isGoogle)
          const ColoredBox(color: Color(0xFFE9ECE8), child: SizedBox.expand())
        else
          _buildFlutterMap(
            state,
            devicesById,
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            satelliteMissingKey: satelliteMissingKey,
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          left: 16,
          child: _ConnectionPill(
            connected: state.liveConnected,
            count: state.devices.length,
            onTap: widget.onPeopleTap,
          ),
        ),
        if (_baseMapError != null || satelliteMissingKey || googleMissingKey)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 72,
            left: 16,
            right: 16,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(
                  googleMissingKey
                      ? 'Google Maps key required'
                      : satelliteMissingKey
                      ? 'Satellite API key required'
                      : 'Map style unavailable',
                ),
                subtitle: Text(
                  googleMissingKey
                      ? 'Add a Google Maps SDK key in Settings. Locations are still live.'
                      : satelliteMissingKey
                      ? 'Add a MapTiler key in Settings. Locations are still live.'
                      : 'Check the connection and retry. Locations are still live.',
                ),
                trailing: satelliteMissingKey || googleMissingKey
                    ? null
                    : TextButton(
                        onPressed: () {
                          setState(() => _baseMapError = null);
                          unawaited(_loadBaseMap(selectedMapStyle));
                        },
                        child: const Text('Retry'),
                      ),
              ),
            ),
          ),
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
    );
  }
  /// Vector (OpenFreeMap) or MapTiler raster map drawn by flutter_map.
  Widget _buildFlutterMap(
    AppState state,
    Map<int, TraccarDevice> devicesById, {
    required LatLng initialCenter,
    required double initialZoom,
    required bool satelliteMissingKey,
  }) {
    final baseMapStyle = _baseMapStyle;
    final selectedMapStyle = state.mapStyle;
    final mapTilerKey = state.mapApiKeys.mapTiler;
    final attribution = baseMapStyle?.attributions
        .map((item) => item.text)
        .where((text) => text.isNotEmpty)
        .join(' · ');
    // Imagery is shown for the MapTiler satellite style, or on top of an
    // OpenFreeMap style once the camera is zoomed in close enough.
    final showImagery =
        mapTilerKey.isNotEmpty &&
        (selectedMapStyle.isSatellite ||
            (state.satelliteWhenZoomed && _zoomedIn));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onLongPress: (_, point) => unawaited(_addPlace(point)),
        onPositionChanged: (camera, _) => _onZoomChanged(camera.zoom),
      ),
      children: [
        if (baseMapStyle != null && !selectedMapStyle.isSatellite)
          vt.VectorTileLayer(
            theme: baseMapStyle.theme,
            tileProviders: baseMapStyle.providers,
            rasterSources: baseMapStyle.rasterSources,
            sprites: baseMapStyle.sprites,
            // Positron omits POIs such as restaurants while retaining
            // useful road and city labels.
            showLabels: true,
            concurrency: 2,
            diskCacheMaximumSizeInBytes: 40 * 1024 * 1024,
          )
        else if (!showImagery)
          const ColoredBox(color: Color(0xFFE9ECE8), child: SizedBox.expand()),
        if (showImagery)
          TileLayer(
            urlTemplate:
                'https://api.maptiler.com/maps/satellite-v4/256/'
                '{z}/{x}/{y}.jpg?key=$mapTilerKey',
            userAgentPackageName: 'com.oneupbyte.trakkar',
            maxNativeZoom: 19,
          ),
        MarkerLayer(
          markers: state.namedPlaces
              .map(
                (place) => Marker(
                  point: LatLng(place.latitude, place.longitude),
                  width: 42,
                  height: 42,
                  child: Tooltip(
                    message: place.name,
                    child: Icon(
                      Icons.bookmark_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 5),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        MarkerLayer(
          // Keep profile photos and their status badges screen-upright
          // while the map rotates underneath them.
          rotate: true,
          markers: state.positions.entries
              .map((entry) {
                final device = devicesById[entry.key];
                final position = entry.value;
                return Marker(
                  point: LatLng(position.latitude, position.longitude),
                  width: 126,
                  height: 64,
                  child: GestureDetector(
                    onTap: device == null
                        ? null
                        : () => unawaited(
                            _showPersonSheet(device, position, state),
                          ),
                    child: _AvatarMarker(
                      name: device?.name ?? 'Unknown',
                      online: device?.status == 'online',
                      position: position,
                      imageBytes: device == null
                          ? null
                          : state.deviceImages[device.id],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
        RichAttributionWidget(
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution(
              showImagery
                  ? '© MapTiler · © OpenStreetMap contributors'
                  : attribution?.isNotEmpty ?? false
                  ? attribution!
                  : 'OpenFreeMap · OpenMapTiles · OpenStreetMap contributors',
            ),
          ],
        ),
      ],
    );
  }

  gm.MapType _googleMapType(AppState state) {
    final imagery = state.satelliteWhenZoomed && _zoomedIn;
    return switch (state.mapStyle) {
      MapStyleOption.googleSatellite => gm.MapType.satellite,
      MapStyleOption.googleHybrid => gm.MapType.hybrid,
      MapStyleOption.googleTerrain =>
        imagery ? gm.MapType.hybrid : gm.MapType.terrain,
      _ => imagery ? gm.MapType.hybrid : gm.MapType.normal,
    };
  }

  /// Native Google Maps SDK map. Profile bubbles are rendered to bitmaps
  /// because native markers cannot host Flutter widgets.
  Widget _buildGoogleMap(
    AppState state,
    Map<int, TraccarDevice> devicesById, {
    required LatLng initialCenter,
    required double initialZoom,
  }) {
    final colors = Theme.of(context).colorScheme;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final brightness = Theme.of(context).brightness;
    final mapType = _googleMapType(state);
    void refresh() {
      if (mounted) setState(() {});
    }

    final placeKey = 'place:${brightness.name}';
    _markerBitmaps.ensure(
      placeKey,
      () => _markerBitmaps.renderPlaceIcon(
        colors: colors,
        pixelRatio: pixelRatio,
      ),
      refresh,
    );
    final placeIcon = _markerBitmaps[placeKey];

    final markers = <gm.Marker>{
      if (placeIcon != null)
        for (final place in state.namedPlaces)
          gm.Marker(
            markerId: gm.MarkerId('place:${place.id}'),
            position: gm.LatLng(place.latitude, place.longitude),
            icon: placeIcon,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 1,
            infoWindow: gm.InfoWindow(title: place.name),
          ),
    };
    for (final entry in state.positions.entries) {
      final device = devicesById[entry.key];
      final position = entry.value;
      final imageBytes = device == null ? null : state.deviceImages[device.id];
      final name = device?.name ?? 'Unknown';
      final online = device?.status == 'online';
      final moving = position.isMoving;
      final speed = position.speedMph.round();
      final key =
          'person:${entry.key}:${identityHashCode(imageBytes)}:$online:'
          '$moving:$speed:${brightness.name}:${_initial(name)}';
      _markerBitmaps.ensure(
        key,
        () => _markerBitmaps.renderAvatar(
          deviceId: entry.key,
          initial: _initial(name),
          online: online,
          moving: moving,
          speedMph: position.speedMph,
          imageBytes: imageBytes,
          colors: colors,
          pixelRatio: pixelRatio,
        ),
        refresh,
      );
      final icon = _markerBitmaps[key];
      if (icon == null) continue;
      markers.add(
        gm.Marker(
          markerId: gm.MarkerId('person:${entry.key}'),
          position: gm.LatLng(position.latitude, position.longitude),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          consumeTapEvents: true,
          onTap: device == null
              ? null
              : () => unawaited(_showPersonSheet(device, position, state)),
        ),
      );
    }

    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(initialCenter.latitude, initialCenter.longitude),
        zoom: initialZoom,
      ),
      mapType: mapType,
      style: mapType == gm.MapType.normal
          ? (brightness == Brightness.dark
                ? googleMapsDarkStyle
                : googleMapsLightStyle)
          : null,
      markers: markers,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      buildingsEnabled: false,
      onMapCreated: (controller) => _googleController = controller,
      onCameraMove: (camera) => _onZoomChanged(camera.zoom),
      onLongPress: (point) =>
          unawaited(_addPlace(LatLng(point.latitude, point.longitude))),
    );
  }
}

class _AvatarMarker extends StatelessWidget {
  const _AvatarMarker({
    required this.name,
    required this.online,
    required this.position,
    required this.imageBytes,
  });

  final String name;
  final bool online;
  final TraccarPosition position;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final showMotion = position.isMoving;
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
                  '${speedMph > 10 ? 'Driving' : 'Walking'}, '
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
                      speedMph > 10 ? '🚗' : '🚶',
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

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({
    required this.connected,
    required this.count,
    required this.onTap,
  });
  final bool connected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected ? const Color(0xFF36A269) : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text('$count ${count == 1 ? 'person' : 'people'}'),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonSheet extends StatelessWidget {
  const _PersonSheet({
    required this.device,
    required this.position,
    required this.imageBytes,
    required this.address,
    required this.onNamePlace,
  });

  final TraccarDevice device;
  final TraccarPosition position;
  final Uint8List? imageBytes;
  final Future<String> address;
  final Future<bool> Function() onNamePlace;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: imageBytes == null
                  ? null
                  : MemoryImage(imageBytes!),
              child: imageBytes == null
                  ? Text(
                      _initial(device.name),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              device.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: address,
              builder: (context, snapshot) => Text(
                snapshot.data ??
                    (snapshot.hasError
                        ? 'Address unavailable'
                        : 'Finding address…'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
