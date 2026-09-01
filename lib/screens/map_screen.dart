import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/traccar_device.dart';
import '../models/traccar_position.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  int? _selectedDeviceId;
  final Map<int, Future<String>> _addressFutures = {};

  void _fitPositions(AppState state) {
    final points = state.positions.values
        .map((position) => LatLng(position.latitude, position.longitude))
        .toList(growable: false);
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 180),
      ),
    );
  }

  Future<void> _addPlace(LatLng point) async {
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
    if ((result ?? false) && name.text.trim().isNotEmpty && mounted) {
      await context.read<AppState>().addNamedPlace(
        name: name.text,
        latitude: point.latitude,
        longitude: point.longitude,
        radiusMeters: double.tryParse(radius.text) ?? 150,
      );
    }
    name.dispose();
    radius.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devicesById = <int, TraccarDevice>{
      for (final device in state.devices) device.id: device,
    };
    final selectedPosition = state.positions[_selectedDeviceId];
    final selectedDevice = devicesById[_selectedDeviceId];
    final initialPosition = state.positions.values.firstOrNull;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialPosition == null
                ? const LatLng(20, 0)
                : LatLng(initialPosition.latitude, initialPosition.longitude),
            initialZoom: initialPosition == null ? 2.5 : 14,
            onLongPress: (_, point) => unawaited(_addPlace(point)),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.oneupbyte.trakkar',
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
              markers: state.positions.entries
                  .map((entry) {
                    final device = devicesById[entry.key];
                    final position = entry.value;
                    final selected = entry.key == _selectedDeviceId;
                    return Marker(
                      point: LatLng(position.latitude, position.longitude),
                      width: 138,
                      height: 72,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedDeviceId = entry.key);
                          _mapController.move(
                            LatLng(position.latitude, position.longitude),
                            _mapController.camera.zoom,
                          );
                        },
                        child: _PersonMarker(
                          name: device?.name ?? 'Unknown',
                          online: device?.status == 'online',
                          selected: selected,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          left: 16,
          child: _ConnectionPill(
            connected: state.liveConnected,
            count: state.positions.length,
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
        if (selectedPosition != null && selectedDevice != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _DeviceCard(
              device: selectedDevice,
              position: selectedPosition,
              address: _addressFutures.putIfAbsent(
                selectedPosition.id,
                () => state.reverseGeocode(selectedPosition),
              ),
              onClose: () => setState(() => _selectedDeviceId = null),
            ),
          ),
      ],
    );
  }
}

class _PersonMarker extends StatelessWidget {
  const _PersonMarker({
    required this.name,
    required this.online,
    required this.selected,
  });

  final String name;
  final bool online;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: online ? const Color(0xFF36A269) : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.location_on_rounded, color: color, size: selected ? 40 : 34),
      ],
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.connected, required this.count});
  final bool connected;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
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
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.position,
    required this.address,
    required this.onClose,
  });

  final TraccarDevice device;
  final TraccarPosition position;
  final Future<String> address;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                device.name.characters.first.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  FutureBuilder<String>(
                    future: address,
                    builder: (context, snapshot) => Text(
                      snapshot.data ??
                          (snapshot.hasError
                              ? 'Address unavailable'
                              : 'Finding address…'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _positionSummary(position),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
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
    return '$clock  •  ${(position.speed * 1.852).round()} km/h';
  }
}
