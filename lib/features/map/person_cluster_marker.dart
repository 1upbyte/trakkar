import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class PersonClusterMarker extends StatelessWidget {
  const PersonClusterMarker({required this.markers, super.key});

  final List<Marker> markers;

  @override
  Widget build(BuildContext context) {
    final count = markers.length;
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Wrap(
          spacing: 1,
          runSpacing: 1,
          children: [
            for (final marker in markers)
              SizedBox(
                width: count == 1 ? 42 : 24,
                height: count == 1 ? 42 : 24,
                child: FittedBox(fit: BoxFit.contain, child: marker.child),
              ),
          ],
        ),
      ),
    );
  }
}
