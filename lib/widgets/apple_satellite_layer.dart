import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

bool get supportsAppleSatellite =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Draws Apple imagery below FlutterMap's interactive layers.
class AppleSatelliteLayer extends StatefulWidget {
  const AppleSatelliteLayer({required this.bottomInset, super.key});

  final double bottomInset;

  @override
  State<AppleSatelliteLayer> createState() => _AppleSatelliteLayerState();
}

class _AppleSatelliteLayerState extends State<AppleSatelliteLayer> {
  static const _viewType = 'com.oneupbyte.trakkar/apple-satellite';
  MethodChannel? _channel;
  Map<String, double> _configuration = const {};

  void _update() {
    final camera = MapCamera.of(context);
    final configuration = {
      'latitude': camera.center.latitude,
      'longitude': camera.center.longitude,
      'worldWidth': camera.crs.scale(camera.zoom),
      'heading': (-camera.rotation) % 360,
      'bottomInset': widget.bottomInset,
    };
    if (mapEquals(_configuration, configuration)) return;
    _configuration = configuration;
    _sendCamera();
  }

  void _sendCamera() {
    unawaited(_channel?.invokeMethod<void>('update', _configuration));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant AppleSatelliteLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bottomInset != oldWidget.bottomInset) _update();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: UiKitView(
      viewType: _viewType,
      creationParams: _configuration,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        if (!mounted) return;
        _channel = MethodChannel('$_viewType/$id');
        _sendCamera();
      },
    ),
  );
}
