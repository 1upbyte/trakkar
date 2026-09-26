import 'package:flutter/material.dart';

import '../../models/place_creation_draft.dart';
import '../../models/saved_place.dart';
import '../../services/places/geofence_repository.dart';
import 'places_list_state.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({
    required this.state,
    required this.onRefresh,
    required this.onPlacesChanged,
    required this.onCreateRequested,
    this.repository,
    super.key,
  });

  final PlacesListState state;
  final GeofenceRepository? repository;
  final Future<List<SavedPlace>> Function() onRefresh;
  final ValueChanged<List<SavedPlace>> onPlacesChanged;
  final Future<void> Function(PlaceCreationMode mode) onCreateRequested;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  Future<void> _chooseCreationMode() async {
    if (widget.repository == null) return;
    final mode = await showDialog<PlaceCreationMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a place'),
        content: const Text('Choose how to define its boundary.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, PlaceCreationMode.auto),
            child: const Text('Auto'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, PlaceCreationMode.manual),
            child: const Text('Manual'),
          ),
        ],
      ),
    );
    if (mode != null && mounted) await widget.onCreateRequested(mode);
  }

  Future<void> _delete(SavedPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${place.name}?'),
        content: Text('This will remove ${place.name} from saved places.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repository = widget.repository;
    if (repository == null) return;
    try {
      await repository.delete(place.id);
      final retained = widget.state.places
          .where((current) => current.id != place.id)
          .toList();
      widget.onPlacesChanged(retained);
      try {
        widget.onPlacesChanged(await widget.onRefresh());
      } on Object {
        _showMessage('Place was deleted, but the list could not refresh.');
      }
    } on Object {
      var reconciled = false;
      try {
        widget.onPlacesChanged(await widget.onRefresh());
        reconciled = true;
      } on Object {
        // Keep the last known server state when reconciliation is unavailable.
      }
      if (mounted) {
        _showMessage(
          reconciled
              ? 'Could not delete place. Server data was refreshed.'
              : 'Could not confirm deletion. Showing the last saved data.',
        );
      }
    }
  }

  Future<void> _refresh() async {
    try {
      widget.onPlacesChanged(await widget.onRefresh());
    } on Object {
      if (mounted) _showMessage('Could not refresh saved places.');
      rethrow;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.repository == null ? null : _chooseCreationMode,
              icon: const Icon(Icons.add),
              label: const Text('Add place'),
            ),
          ),
        ),
        Expanded(child: _listContent(state)),
      ],
    );
  }

  Widget _listContent(PlacesListState state) {
    if (state.isLoading && state.places.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError && state.places.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load saved places.'),
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (state.places.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Center(child: Text('No saved places yet.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        key: const PageStorageKey<String>('places-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.places.length,
        itemBuilder: (context, index) {
          final place = state.places[index];
          return ListTile(
            key: ValueKey('saved-place-${place.id}'),
            leading: const Icon(Icons.place_outlined),
            title: Text(place.name),
            subtitle: Text(_geometryLabel(place)),
            trailing: IconButton(
              tooltip: 'Delete ${place.name}',
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.repository == null
                  ? null
                  : () => _delete(place),
            ),
          );
        },
      ),
    );
  }

  String _geometryLabel(SavedPlace place) => switch (place.geometryType) {
    SavedPlaceGeometry.point => 'Point',
    SavedPlaceGeometry.circle => 'Circular area',
    SavedPlaceGeometry.polygon => 'Area',
  };
}
