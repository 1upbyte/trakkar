import 'package:flutter/material.dart';

import '../../models/server_details.dart';

class ServerDetailsSection extends StatelessWidget {
  const ServerDetailsSection({required this.details, super.key});

  final ServerDetails details;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Server details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _DetailRow(label: 'Client server', value: details.clientUrl),
          _DetailRow(label: 'Manager server', value: details.managerUrl),
          _DetailRow(label: 'Account', value: details.accountName),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 126, child: Text(label)),
        Expanded(child: SelectableText(value ?? 'Unavailable')),
      ],
    ),
  );
}
