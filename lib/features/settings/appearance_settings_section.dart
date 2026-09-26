import 'package:flutter/material.dart';

import '../../models/map_appearance_preference.dart';
import '../../models/theme_preference.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({
    required this.themePreference,
    required this.mapAppearance,
    required this.onThemeChanged,
    required this.onThresholdChanged,
    super.key,
  });

  final AppThemePreference themePreference;
  final MapAppearancePreference mapAppearance;
  final ValueChanged<AppThemePreference> onThemeChanged;
  final ValueChanged<double> onThresholdChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<AppThemePreference>(
            segments: const [
              ButtonSegment(
                value: AppThemePreference.system,
                label: Text('System'),
              ),
              ButtonSegment(
                value: AppThemePreference.light,
                label: Text('Light'),
              ),
              ButtonSegment(
                value: AppThemePreference.dark,
                label: Text('Dark'),
              ),
            ],
            selected: {themePreference},
            onSelectionChanged: (selection) => onThemeChanged(selection.single),
          ),
          const SizedBox(height: 20),
          Text(
            'Switch to satellite at zoom ${mapAppearance.satelliteThresholdZoom.toStringAsFixed(0)}',
          ),
          Slider(
            value: mapAppearance.satelliteThresholdZoom,
            min: 15,
            max: 21,
            divisions: 6,
            label: mapAppearance.satelliteThresholdZoom.toStringAsFixed(0),
            onChanged: onThresholdChanged,
          ),
        ],
      ),
    ),
  );
}
