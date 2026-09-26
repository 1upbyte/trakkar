import 'package:flutter/material.dart';

import '../../models/reset_request.dart';

class ResetSettingsSection extends StatelessWidget {
  const ResetSettingsSection({
    required this.request,
    required this.enabled,
    required this.onReset,
    super.key,
  });

  final ResetRequest request;
  final bool enabled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reset app', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Clear this app’s sign-in and server addresses, restore System theme '
            'and the map zoom threshold to 19, and return to setup. Your server '
            'account, profile picture, places, tracking data, and queued positions '
            'will remain.',
          ),
          const SizedBox(height: 8),
          if (request.isActive) ...[
            const LinearProgressIndicator(),
            Text(_statusText(request.status)),
          ],
          if (request.status == ResetStatus.failed)
            Text(
              request.failureMessage ?? 'Reset could not finish. Your account is still available to retry.',
            ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: enabled && !request.isActive ? onReset : null,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset app'),
            ),
          ),
        ],
      ),
    ),
  );

  String _statusText(ResetStatus status) => switch (status) {
    ResetStatus.stoppingTracking => 'Stopping tracking…',
    ResetStatus.clearingLocalConfig => 'Clearing local setup…',
    _ => 'Resetting…',
  };
}
