import 'package:flutter/material.dart';

import '../../models/person.dart';

class PersonDetailsSheet extends StatelessWidget {
  const PersonDetailsSheet({
    required this.person,
    required this.locationDescription,
    super.key,
  });

  final PersonMapEntry person;
  final Future<String> locationDescription;

  @override
  Widget build(BuildContext context) {
    final stale =
        person.fixTime == null ||
        DateTime.now().difference(person.fixTime!) >
            const Duration(minutes: 15);
    final lastUpdate = person.fixTime == null
        ? 'Unknown'
        : '${person.fixTime!.toLocal()}${stale ? ' · Last known' : ''}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              person.displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: locationDescription,
              builder: (context, snapshot) => _DetailRow(
                label: 'Location',
                value: snapshot.data ?? 'Loading location…',
              ),
            ),
            _DetailRow(
              label: 'Battery',
              value: person.batteryLevel == null
                  ? 'Unknown'
                  : '${person.batteryLevel!.round()}%',
            ),
            _DetailRow(label: 'Last update', value: lastUpdate),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
