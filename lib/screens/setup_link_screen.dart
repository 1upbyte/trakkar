import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/provisioning_config.dart';
import 'onboarding_screen.dart';

class SetupLinkScreen extends StatefulWidget {
  const SetupLinkScreen({required this.link, super.key});

  final String link;

  @override
  State<SetupLinkScreen> createState() => _SetupLinkScreenState();
}

class _SetupLinkScreenState extends State<SetupLinkScreen> {
  ProvisioningConfig? _config;
  bool _started = false;
  bool _resetting = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    try {
      _config = ProvisioningConfig.fromSetupLink(widget.link);
    } on FormatException {
      // Never echo the URL: it contains account credentials.
    }
  }

  Future<void> _continue(AppState state) async {
    setState(() => _resetting = true);
    if (state.phase == AppPhase.ready) {
      await state.resetApp();
    } else {
      state.clearPendingProvisioning();
    }
    if (!mounted) return;
    setState(() {
      _resetting = false;
      _started = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final config = _config;
    if (_started && state.phase == AppPhase.ready && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    final waiting = state.phase == AppPhase.loading || _resetting;
    return PopScope(
      canPop: !_resetting && !state.busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _started && state.phase == AppPhase.onboarding) {
          state.clearPendingProvisioning();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Set up Trakkar')),
        body: config == null
            ? const Center(child: Text('This setup link is invalid or incomplete.'))
            : waiting || _closing
            ? const Center(child: CircularProgressIndicator())
            : _started
            ? OnboardingScreen(initialConfig: config)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log in with this setup?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text('Manager: ${config.managerUrl}'),
                    Text('Client: ${config.clientUrl}'),
                    if (config.liveTrackingUrl != null)
                      Text('Live tracking: ${config.liveTrackingUrl}'),
                    Text('Account: ${config.managerUsername}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Continue to review the connection details and log in. '
                      'Location sharing starts after you complete your profile.',
                    ),
                    if (state.phase == AppPhase.ready) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Continuing stops tracking and replaces the setup on '
                        'this phone. Your current local profile will be cleared.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.busy ? null : () => _continue(state),
                      child: Text(
                        state.phase == AppPhase.ready
                            ? 'Replace setup and continue'
                            : 'Continue to login',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
