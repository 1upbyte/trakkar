import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class PlacesScreen extends StatelessWidget {
  const PlacesScreen({this.selectedPlaceId, super.key});

  final String? selectedPlaceId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final places = [...state.namedPlaces];
    if (selectedPlaceId != null) {
      places.sort(
        (a, b) => a.id == selectedPlaceId
            ? -1
            : b.id == selectedPlaceId
            ? 1
            : 0,
      );
    }
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Named places',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Long-press the map to add a circular place, or use Draw '
                    'place to trace its boundary or Auto to select buildings.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.namedPlaces.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 54),
                    SizedBox(height: 12),
                    Text('No named places yet'),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              sliver: SliverList.separated(
                itemCount: state.namedPlaces.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final place = places[index];
                  return Card(
                    color: place.id == selectedPlaceId
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        child: Icon(
                          Icons.place_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        place.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${place.isPolygon ? 'Drawn area  •  ${place.boundary.length} corners' : '${place.latitude.toStringAsFixed(5)}, '
                                  '${place.longitude.toStringAsFixed(5)}  •  '
                                  '${place.radiusMeters.round()} m'}\n'
                        'Exit alerts ${place.notifyOnExit ? 'on' : 'off'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete place',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete ${place.name}?'),
                              content: const Text(
                                'This removes the shared name for everyone on '
                                'this Traccar account.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed ?? false) {
                            try {
                              await state.deleteNamedPlace(place.id);
                            } on Object {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      state.lastError ?? 'The shared place could not be deleted.',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
