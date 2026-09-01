import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/reverse_geocoder.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _templateController = TextEditingController();
  GeocodingProvider? _provider;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      final settings = context.read<AppState>().geocodingSettings;
      _provider = settings.provider;
      _apiKeyController.text = settings.apiKey;
      _templateController.text = settings.customUrlTemplate;
      _seeded = true;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  Future<void> _saveGeocoding() async {
    await context.read<AppState>().saveGeocodingSettings(
      GeocodingSettings(
        provider: _provider ?? GeocodingProvider.traccarServer,
        apiKey: _apiKeyController.text,
        customUrlTemplate: _templateController.text,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverse geocoding settings saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final provider = _provider ?? GeocodingProvider.traccarServer;
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          state.firstName.characters.first.toUpperCase(),
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
            'Reverse geocoding',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Named places always take priority. These settings resolve other '
            'coordinates into street addresses.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  DropdownButtonFormField<GeocodingProvider>(
                    initialValue: provider,
                    decoration: const InputDecoration(labelText: 'Provider'),
                    items: GeocodingProvider.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_providerLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => _provider = value),
                  ),
                  if (provider != GeocodingProvider.traccarServer) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: provider == GeocodingProvider.custom
                            ? 'API key (optional)'
                            : 'API key',
                        prefixIcon: const Icon(Icons.key_outlined),
                      ),
                    ),
                  ],
                  if (provider == GeocodingProvider.custom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _templateController,
                      autocorrect: false,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'URL template',
                        helperText: 'Use {lat}, {lon}, and optionally {key}',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveGeocoding,
                      child: const Text('Save geocoding settings'),
                    ),
                  ),
                ],
              ),
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

  static String _providerLabel(GeocodingProvider provider) {
    return switch (provider) {
      GeocodingProvider.traccarServer => 'Traccar server',
      GeocodingProvider.geoapify => 'Geoapify',
      GeocodingProvider.mapTiler => 'MapTiler',
      GeocodingProvider.custom => 'Custom HTTP endpoint',
    };
  }
}
