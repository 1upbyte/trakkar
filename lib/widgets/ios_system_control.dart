import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get usesIOSSystemControls => !kIsWeb && Platform.isIOS;

/// Uses current UIKit controls, including the system's glass switch/slider thumb.
class IOSSystemControl extends StatefulWidget {
  const IOSSystemControl({
    required this.kind,
    required this.configuration,
    this.onChanged,
    super.key,
  });

  final String kind;
  final Map<String, Object?> configuration;
  final ValueChanged<Object?>? onChanged;

  @override
  State<IOSSystemControl> createState() => _IOSSystemControlState();
}

class _IOSSystemControlState extends State<IOSSystemControl> {
  MethodChannel? _channel;

  Map<String, Object?> get _configuration => {
    ...widget.configuration,
    'kind': widget.kind,
    'enabled': widget.onChanged != null,
    'dark': Theme.of(context).brightness == Brightness.dark,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant IOSSystemControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    _channel?.invokeMethod<void>('update', _configuration);
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'com.oneupbyte.trakkar/system-control',
    // Claim horizontal drags before the surrounding scrollable can delay or
    // reject UIKit's slider gesture. Vertical drags still scroll the page.
    gestureRecognizers: {
      if (widget.kind == 'slider' && widget.onChanged != null)
        Factory<HorizontalDragGestureRecognizer>(
          HorizontalDragGestureRecognizer.new,
        ),
    },
    creationParams: _configuration,
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: (id) {
      if (!mounted) return;
      _channel = MethodChannel('com.oneupbyte.trakkar/system-control/$id');
      _channel!.setMethodCallHandler((call) async {
        if (mounted && call.method == 'changed') {
          widget.onChanged?.call(call.arguments);
        }
      });
      _update();
    },
  );
}
