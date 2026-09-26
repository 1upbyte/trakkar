import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../../app/app_theme.dart';
import '../../models/reset_request.dart';
import '../../models/map_appearance_preference.dart';
import '../../models/server_details.dart';
import '../../services/settings/app_reset_service.dart' show AppResetFailure;
import 'settings_state.dart';
import 'appearance_settings_section.dart';
import 'profile_settings_section.dart';
import 'reset_settings_section.dart';
import 'server_details_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.state,
    required this.themeController,
    required this.serverDetails,
    required this.onReset,
    required this.onProfileChanged,
    required this.mapAppearance,
    required this.onThresholdChanged,
    this.imageLoader,
    super.key,
  });

  final SettingsState? state;
  final AppThemeController themeController;
  final ServerDetails serverDetails;
  final Future<void> Function() onReset;
  final Future<Uint8List> Function(String reference)? imageLoader;
  final VoidCallback onProfileChanged;
  final MapAppearancePreference mapAppearance;
  final ValueChanged<double> onThresholdChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ResetRequest _reset = const ResetRequest();

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this app?'),
        content: const Text(
          'This clears local sign-in details, server addresses, and SDK connection '
          'configuration, then restores System theme and map threshold 19. Your '
          'server account, profile picture, places, tracking data, and queued '
          'positions are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset app'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(
      () => _reset = const ResetRequest(status: ResetStatus.stoppingTracking),
    );
    try {
      await widget.onReset();
      if (mounted) {
        setState(
          () => _reset = const ResetRequest(status: ResetStatus.complete),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _reset = ResetRequest(
            status: ResetStatus.failed,
            failureMessage: error is AppResetFailure ? error.message : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.state, widget.themeController]),
    builder: (context, _) {
      final state = widget.state;
      if (state == null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Profile details are unavailable until you sign in.',
                ),
              ),
            ),
            AppearanceSettingsSection(
              themePreference: widget.themeController.preference,
              mapAppearance: widget.mapAppearance,
              onThemeChanged: widget.themeController.select,
              onThresholdChanged: widget.onThresholdChanged,
            ),
            ServerDetailsSection(details: widget.serverDetails),
            ResetSettingsSection(
              request: _reset,
              enabled: true,
              onReset: _confirmReset,
            ),
          ],
        );
      }
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProfileSettingsSection(
            profile: state.profile,
            isSavingName: state.isSavingName,
            isSavingImage: state.isSavingImage,
            imageLoader: widget.imageLoader,
            onSaveName: (name) async {
              final saved = await state.updateDisplayName(name);
              if (saved) widget.onProfileChanged();
              return saved;
            },
            onSaveImage: (bytes, contentType) async {
              final saved = await state.updateProfileImage(
                bytes: bytes,
                contentType: contentType,
              );
              if (saved) widget.onProfileChanged();
              return saved;
            },
          ),
          if (state.errorMessage case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          AppearanceSettingsSection(
            themePreference: widget.themeController.preference,
            mapAppearance: state.mapAppearance,
            onThemeChanged: widget.themeController.select,
            onThresholdChanged: widget.onThresholdChanged,
          ),
          ServerDetailsSection(
            details: ServerDetails.redacted(
              clientUrl: widget.serverDetails.clientUrl,
              managerUrl: widget.serverDetails.managerUrl,
              accountName:
                  state.profile?.displayName ??
                  widget.serverDetails.accountName,
            ),
          ),
          ResetSettingsSection(
            request: _reset,
            enabled: !state.isSaving,
            onReset: _confirmReset,
          ),
        ],
      );
    },
  );
}
