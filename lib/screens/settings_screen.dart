import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/map_api_keys.dart';
import '../models/map_style_option.dart';
import '../models/theme_preference.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _googleMapsKeyController = TextEditingController();
  final _mapTilerKeyController = TextEditingController();
  MapStyleOption? _mapStyle;
  MapApiKeys _seededKeys = const MapApiKeys();
  bool _seeded = false;
  bool _savingMap = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (!_seeded) {
      _mapStyle = state.mapStyle;
      _seeded = true;
    }
    // Keys can arrive from the server after this screen was first built.
    // Refresh untouched fields so another phone's keys show up here.
    if (state.mapApiKeys != _seededKeys) {
      if (_googleMapsKeyController.text.trim() == _seededKeys.googleMaps) {
        _googleMapsKeyController.text = state.mapApiKeys.googleMaps;
      }
      if (_mapTilerKeyController.text.trim() == _seededKeys.mapTiler) {
        _mapTilerKeyController.text = state.mapApiKeys.mapTiler;
      }
      _seededKeys = state.mapApiKeys;
    }
  }

  @override
  void dispose() {
    _googleMapsKeyController.dispose();
    _mapTilerKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveMapAppearance() async {
    setState(() => _savingMap = true);
    try {
      await context.read<AppState>().saveMapAppearance(
        style: _mapStyle ?? MapStyleOption.positron,
        keys: MapApiKeys(
          googleMaps: _googleMapsKeyController.text,
          mapTiler: _mapTilerKeyController.text,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map appearance saved and shared with the account.'),
          ),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (error) {
      if (mounted) {
        final message =
            context.read<AppState>().lastError ??
            (error is Exception ? error.toString() : 'Map settings failed.');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _savingMap = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (selected == null || !mounted) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      final contentType = _imageContentType(bytes) ?? selected.mimeType;
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
    final mapStyle = _mapStyle ?? MapStyleOption.positron;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
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
                                backgroundImage:
                                    state.ownDevice == null ||
                                        state.deviceImages[state
                                                .ownDevice!
                                                .id] ==
                                            null
                                    ? null
                                    : MemoryImage(
                                        state.deviceImages[state
                                            .ownDevice!
                                            .id]!,
                                      ),
                                child:
                                    state.ownDevice == null ||
                                        state.deviceImages[state
                                                .ownDevice!
                                                .id] ==
                                            null
                                    ? Text(
                                        state.firstName.characters.first
                                            .toUpperCase(),
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
            'Google Maps uses the free mobile Maps SDK. OpenFreeMap styles need '
            'no key. MapTiler provides satellite imagery for OpenFreeMap styles. '
            'Keys are stored on the Traccar server and shared with every phone '
            'on this account.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<MapStyleOption>(
                    initialValue: mapStyle,
                    decoration: const InputDecoration(labelText: 'Map style'),
                    items: MapStyleOption.values
                        .map(
                          (style) => DropdownMenuItem(
                            value: style,
                            child: Text(style.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => _mapStyle = value),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Satellite when zoomed in'),
                    subtitle: Text(
                      mapStyle.alwaysImagery
                          ? 'This style already shows imagery at every zoom.'
                          : 'Street map when zoomed out, imagery close up. '
                                '${mapStyle.isGoogle ? 'Uses Google hybrid tiles.' : 'Needs a MapTiler key.'}',
                    ),
                    value: state.satelliteWhenZoomed,
                    onChanged: mapStyle.alwaysImagery
                        ? null
                        : state.setSatelliteWhenZoomed,
                  ),
                  const Divider(height: 24),
                  Text(
                    'Shared map keys',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _googleMapsKeyController,
                    obscureText: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Google Maps SDK key',
                      helperText: mapStyle.isGoogle
                          ? 'Required for Google Maps styles.'
                          : 'Optional until a Google Maps style is chosen.',
                      prefixIcon: const Icon(Icons.key_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mapTilerKeyController,
                    obscureText: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'MapTiler API key',
                      helperText: mapStyle.isSatellite
                          ? 'Required for MapTiler satellite.'
                          : 'Optional. Enables zoomed-in imagery on '
                                'OpenFreeMap styles.',
                      prefixIcon: const Icon(Icons.satellite_alt_outlined),
                    ),
                  ),
                  if (state.mapApiKeys.googleMaps.isNotEmpty &&
                      !state.googleMapsKeyApplied) ...[
                    const SizedBox(height: 8),
                    Text(
                      'The Google Maps key could not be applied on this phone. '
                      'Restart the app, or add a build-time key for Android 10 '
                      'and earlier.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _savingMap ? null : _saveMapAppearance,
                      child: Text(
                        _savingMap ? 'Saving…' : 'Save map appearance',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.watchers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Live sharing active'),
                subtitle: Text(
                  '${state.watchers.join(', ')} '
                  '${state.watchers.length == 1 ? 'has' : 'have'} the map '
                  'open, so this phone is sending fresh positions.',
                ),
              ),
            ),
          ],
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
