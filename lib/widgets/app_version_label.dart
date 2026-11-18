import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({
    this.releaseName = const String.fromEnvironment('TRAKKAR_RELEASE_NAME'),
    super.key,
  });

  final String releaseName;

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final _packageInfo = PackageInfo.fromPlatform();

  Widget _label(String text) => Semantics(
    identifier: 'app-version',
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final release = widget.releaseName.trim();
    if (Theme.of(context).platform == TargetPlatform.android &&
        release.isNotEmpty) {
      return _label('Release $release');
    }
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) {
          return snapshot.hasError
              ? _label('Version unavailable')
              : const SizedBox.shrink();
        }
        final parts = [
          if (info.version.isNotEmpty) 'Version ${info.version}',
          if (info.buildNumber.isNotEmpty) 'Build ${info.buildNumber}',
        ];
        return _label(
          parts.isEmpty ? 'Version unavailable' : parts.join(' · '),
        );
      },
    );
  }
}
