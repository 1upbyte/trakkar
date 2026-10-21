import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../user_facing_error.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _clientUrlController = TextEditingController();
  final _liveTrackingUrlController = TextEditingController();
  final _managerUrlController = TextEditingController();
  final _managerUsernameController = TextEditingController();
  final _managerPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _scanning = false;
  bool _handlingScan = false;
  bool _showManual = false;
  bool _showManagerPassword = false;
  String? _connectionError;

  @override
  void dispose() {
    _clientUrlController.dispose();
    _managerUrlController.dispose();
    _liveTrackingUrlController.dispose();
    _managerUsernameController.dispose();
    _managerPasswordController.dispose();
    _firstNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _accept(String value) async {
    if (_handlingScan) return;
    _handlingScan = true;
    try {
      await context.read<AppState>().acceptQr(value);
      if (mounted) {
        setState(() {
          _scanning = false;
          _connectionError = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _connectionError = userFacingError(error);
        });
      }
    } finally {
      _handlingScan = false;
    }
  }

  Future<void> _acceptManual() async {
    try {
      await context.read<AppState>().acceptManual(
        clientUrl: _clientUrlController.text,
        managerUrl: _managerUrlController.text,
        liveTrackingUrl: _liveTrackingUrlController.text,
        managerUsername: _managerUsernameController.text,
        managerPassword: _managerPasswordController.text,
      );
      if (mounted) setState(() => _connectionError = null);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _connectionError = userFacingError(error));
      }
    }
  }

  Future<void> _submitProfile({bool replace = false}) async {
    final state = context.read<AppState>();
    try {
      await state.completeProfile(
        firstName: _firstNameController.text,
        username: _usernameController.text,
        replace: replace,
      );
    } on DeviceConflictException catch (conflict) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Username already in use'),
          content: Text(
            '“${conflict.device.uniqueId}” is currently connected as '
            '“${conflict.device.name}”. Continuing will make this phone the '
            'location source for that device and update its name.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Choose another'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed ?? false) {
        await _submitProfile(replace: true);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profileStep = state.pendingProvisioning != null;
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: profileStep ? _profileStep(state) : _serverStep(state),
        ),
      ),
    );
  }

  Widget _serverStep(AppState state) {
    if (_scanning) {
      return Stack(
        key: const ValueKey('scanner'),
        children: [
          MobileScanner(
            onDetect: (capture) {
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value != null) unawaited(_accept(value));
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: IconButton.filledTonal(
              onPressed: () => setState(() => _scanning = false),
              icon: const Icon(Icons.close),
            ),
          ),
          const Positioned(
            left: 32,
            right: 32,
            bottom: 56,
            child: Text(
              'Point your camera at the Trakkar server QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.near_me_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 34),
          Text(
            'Stay close,\nwherever you are.',
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.05),
          ),
          const SizedBox(height: 16),
          Text(
            'Connect to your private Traccar server to share your location '
            'and see your people move in real time.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: state.busy
                  ? null
                  : () => setState(() => _scanning = true),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan server code'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _showManual = !_showManual),
              child: Text(
                _showManual
                    ? 'Hide connection details'
                    : 'Enter connection details manually',
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _showManual
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _clientUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Client URL',
                    hintText: 'https://client.example.com',
                    prefixIcon: Icon(Icons.upload_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _managerUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Manager URL',
                    hintText: 'https://manager.example.com',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _liveTrackingUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Live tracking URL (optional)',
                    hintText: 'https://live.example.com',
                    helperText: 'Leave blank to disable live tracking.',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _managerUsernameController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Manager username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _managerPasswordController,
                  obscureText: !_showManagerPassword,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: state.busy ? null : (_) => _acceptManual(),
                  decoration: InputDecoration(
                    labelText: 'Manager password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showManagerPassword
                          ? 'Hide password'
                          : 'Show password',
                      onPressed: () => setState(
                        () => _showManagerPassword = !_showManagerPassword,
                      ),
                      icon: Icon(
                        _showManagerPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: state.busy ? null : _acceptManual,
                    child: state.busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                ),
              ],
            ),
          ),
          if (_connectionError != null) ...[
            const SizedBox(height: 16),
            _ConnectionError(message: _connectionError!),
          ],
          const SizedBox(height: 28),
          const _PrivacyNote(),
        ],
      ),
    );
  }

  Widget _profileStep(AppState state) {
    return SingleChildScrollView(
      key: const ValueKey('profile'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: state.busy ? null : state.clearPendingProvisioning,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(height: 28),
          Icon(
            Icons.verified_user_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Make it yours',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Your first name identifies you on the map. Your username is also the '
            'unique device ID sent by the official Traccar SDK.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          AutofillGroup(
            child: Column(
              children: [
                TextField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _usernameController,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'Letters, numbers, dots, dashes, underscores',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: state.busy ? null : _submitProfile,
              child: state.busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Start sharing'),
            ),
          ),
          const SizedBox(height: 24),
          const _PrivacyNote(),
        ],
      ),
    );
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Server credentials are kept in secure device storage. Location '
            'tracking is performed only by the Traccar Client SDK.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
