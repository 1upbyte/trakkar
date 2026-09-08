import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/theme_preference.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _saveMapAppearance({
    bool? darkMap,
    bool? satelliteAutoAtStreetZoom,
    bool? satelliteAlways,
    double? satelliteZoom,
  }) async {
    try {
      await context.read<AppState>().saveMapAppearance(
        darkMap: darkMap,
        satelliteAutoAtStreetZoom: satelliteAutoAtStreetZoom,
        satelliteAlways: satelliteAlways,
        satelliteZoom: satelliteZoom,
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Map changes could not be saved. Please try again.'),
        ),
      );
    }
  }

  Future<void> _pickProfilePicture() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (selected == null || !mounted) return;
      final colors = Theme.of(context).colorScheme;
      final lightSystemBars =
          ThemeData.estimateBrightnessForColor(colors.surface) ==
          Brightness.light;
      final cropped = await ImageCropper().cropImage(
        sourcePath: selected.path,
        maxWidth: 512,
        maxHeight: 512,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 82,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile picture',
            toolbarColor: colors.surface,
            toolbarWidgetColor: colors.onSurface,
            activeControlsWidgetColor: colors.primary,
            statusBarLight: lightSystemBars,
            navBarLight: lightSystemBars,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop profile picture',
            doneButtonTitle: 'Use photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          WebUiSettings(context: context),
        ],
      );
      if (cropped == null || !mounted) return;
      final bytes = await cropped.readAsBytes();
      if (!mounted) return;
      final contentType = _imageContentType(bytes);
      if (contentType == null) {
        throw const FormatException(
          'Choose a JPEG, PNG, GIF, or WebP profile picture.',
        );
      }
      await context.read<AppState>().updateProfilePicture(bytes, contentType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated.')),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      final stateMessage = context.read<AppState>().lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stateMessage ??
                (error is FormatException
                    ? error.message
                    : 'The profile picture could not be updated.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final ownImage = state.ownDevice == null
        ? null
        : state.deviceImages[state.ownDevice!.id];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Text(
            'Account',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Change profile picture',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: state.busy ? null : _pickProfilePicture,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: ownImage == null
                                    ? null
                                    : MemoryImage(ownImage),
                                child: ownImage == null
                                    ? Text(
                                        _initial(state.firstName),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -3,
                                bottom: -3,
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  child: const Icon(
                                    Icons.edit,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.firstName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text('@${state.deviceUsername}'),
                            const SizedBox(height: 2),
                            Text(
                              'Tap the picture to change it',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Share my location'),
                    subtitle: const Text('Powered only by Traccar Client SDK'),
                    value: state.tracking,
                    onChanged: state.busy ? null : state.setTracking,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: state.busy
                          ? null
                          : () async {
                              final sent = await state.sendPositionNow();
                              if (context.mounted && sent) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Position sent by the SDK.'),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Send a position now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemePreference>(
                      segments: ThemePreference.values
                          .map(
                            (preference) => ButtonSegment(
                              value: preference,
                              label: Text(preference.label),
                            ),
                          )
                          .toList(growable: false),
                      selected: {state.themePreference},
                      onSelectionChanged: (selection) {
                        state.setThemePreference(selection.single);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'System follows your phone’s light or dark appearance.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Map appearance',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose when to show satellite imagery. Changes save automatically.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark map'),
                  subtitle: const Text(
                    'Use a dark street map. Satellite imagery keeps its natural colors.',
                  ),
                  value: state.darkMap,
                  onChanged: (value) => _saveMapAppearance(darkMap: value),
                ),
                SwitchListTile(
                  title: const Text('Satellite at street level'),
                  subtitle: const Text(
                    'Show satellite imagery automatically when zoomed in.',
                  ),
                  value: state.satelliteAutoAtStreetZoom,
                  onChanged: state.satelliteAlways
                      ? null
                      : (value) => _saveMapAppearance(
                          satelliteAutoAtStreetZoom: value,
                        ),
                ),
                SwitchListTile(
                  title: const Text('Always satellite'),
                  subtitle: const Text(
                    'Show satellite imagery at every zoom level.',
                  ),
                  value: state.satelliteAlways,
                  onChanged: (value) =>
                      _saveMapAppearance(satelliteAlways: value),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Satellite starts at zoom ${state.satelliteZoom.toStringAsFixed(1)}',
                      ),
                      Slider(
                        value: state.satelliteZoom,
                        min: 2,
                        max: 21,
                        divisions: 38,
                        label: state.satelliteZoom.toStringAsFixed(1),
                        onChanged:
                            state.satelliteAlways ||
                                !state.satelliteAutoAtStreetZoom
                            ? null
                            : (value) =>
                                  _saveMapAppearance(satelliteZoom: value),
                      ),
                      const Text(
                        'Lower values switch sooner; higher values switch closer in.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connection',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_rounded),
                  title: const Text('Client endpoint'),
                  subtitle: Text(
                    state.provisioning?.clientUrl.host ?? 'Not connected',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Manager endpoint'),
                  subtitle: Text(
                    state.provisioning?.managerUrl.host ?? 'Not connected',
                  ),
                  trailing: Icon(
                    state.liveConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: state.liveConnected ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Trakkar?'),
                  content: const Text(
                    'This stops tracking and removes the server credentials, '
                    'profile, and named places stored on this phone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if ((confirmed ?? false) && context.mounted) {
                await context.read<AppState>().resetApp();
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Reset app'),
          ),
        ],
      ),
    );
  }

  static String _initial(String name) {
    final clean = name.trim();
    return clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
  }

  static String? _imageContentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 6 && String.fromCharCodes(bytes.take(3)) == 'GIF') {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }
}
