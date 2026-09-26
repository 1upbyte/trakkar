import 'package:flutter/material.dart';

import '../../services/auth/setup_controller.dart';
import '../../widgets/server_connection_banner.dart';

class SetupRecoveryView extends StatefulWidget {
  const SetupRecoveryView({required this.controller, super.key});

  final SetupController controller;

  @override
  State<SetupRecoveryView> createState() => _SetupRecoveryViewState();
}

class _SetupRecoveryViewState extends State<SetupRecoveryView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final failure = widget.controller.failure;
    if (failure == null) return const SizedBox.shrink();
    final isRejected = failure.isRejectedCredentials;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign-in issue')),
      body: Column(
        children: [
          if (!isRejected)
            ServerConnectionBanner(
              message: 'Connection to server failed',
              actionLabel: 'Retry',
              onAction: widget.controller.retry,
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRejected ? Icons.lock_outline : Icons.cloud_off,
                        size: 44,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isRejected
                            ? 'The username or password was not accepted.'
                            : '${failure.service.name[0].toUpperCase()}${failure.service.name.substring(1)} service is unavailable.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!isRejected && failure.safeDetails != null) ...[
                        TextButton(
                          onPressed: () =>
                              setState(() => _showDetails = !_showDetails),
                          child: Text(
                            _showDetails
                                ? 'Hide full error'
                                : 'View full error',
                          ),
                        ),
                        if (_showDetails)
                          SelectableText(
                            failure.safeDetails!,
                            textAlign: TextAlign.center,
                          ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.controller.backToEditing,
                        child: const Text('Back'),
                      ),
                      OutlinedButton(
                        onPressed: widget.controller.retry,
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: widget.controller.proceedAnyway,
                        child: const Text('Proceed Anyway'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
