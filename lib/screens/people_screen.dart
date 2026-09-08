import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/location_label.dart';
import '../models/traccar_device.dart';
import '../models/traccar_position.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final Map<String, Future<String>> _addressCache = {};

  Future<String> _addressFor(AppState state, TraccarPosition position) {
    if (_addressCache.length > 100) _addressCache.clear();
    final key =
        '${position.deviceId}:'
        '${position.latitude.toStringAsFixed(4)}:'
        '${position.longitude.toStringAsFixed(4)}';
    return _addressCache.putIfAbsent(
      key,
      () => state
          .reverseGeocode(position)
          .catchError((Object _) => locationFallback(position)),
    );
  }

  Widget _personTile(AppState state, TraccarDevice device) {
    final position = state.positions[device.id];
    final friendlyPlace = position == null
        ? null
        : state.friendlyPlaceFor(position);
    return _PersonTile(
      device: device,
      position: position,
      imageBytes: state.deviceImages[device.id],
      friendlyPlace: friendlyPlace,
      // Do not make a reverse-geocoding request when a shared friendly place
      // already covers this position.
      address: position == null || friendlyPlace != null
          ? null
          : _addressFor(state, position),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final people = [...state.devices]
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'People',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${people.length} ${people.length == 1 ? 'person' : 'people'} '
              'shared with this account',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (people.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.group_outlined, size: 40),
                      SizedBox(height: 10),
                      Text('No people are available yet.'),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var index = 0; index < people.length; index++) ...[
                      _personTile(state, people[index]),
                      if (index != people.length - 1)
                        const Divider(height: 1, indent: 76),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.device,
    required this.position,
    required this.imageBytes,
    required this.friendlyPlace,
    required this.address,
  });

  final TraccarDevice device;
  final TraccarPosition? position;
  final Uint8List? imageBytes;
  final String? friendlyPlace;
  final Future<String>? address;

  @override
  Widget build(BuildContext context) {
    final image = imageBytes;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: image == null ? null : MemoryImage(image),
            child: image == null
                ? Text(
                    _initial(device.name),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  )
                : null,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: device.status == 'online'
                    ? const Color(0xFF36A269)
                    : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        device.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _LocationText(
          position: position,
          friendlyPlace: friendlyPlace,
          address: address,
        ),
      ),
      trailing: position?.isMoving == true
          ? Text(
              '${position!.speedMph > 10 ? '🚗' : '🚶'} '
              '${position!.speedMph.round()} mph',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
    );
  }
}

class _LocationText extends StatelessWidget {
  const _LocationText({
    required this.position,
    required this.friendlyPlace,
    required this.address,
  });

  final TraccarPosition? position;
  final String? friendlyPlace;
  final Future<String>? address;

  @override
  Widget build(BuildContext context) {
    if (position == null) return const Text('No location reported');
    return LocationLabel(
      position: position!,
      friendlyPlace: friendlyPlace,
      address: address,
    );
  }
}

String _initial(String name) {
  final clean = name.trim();
  return clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
}
