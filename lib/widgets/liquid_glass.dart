import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The material is rendered by UIKit on iPhone, above the Flutter content.
/// Desktop previews and older iOS versions use a frosted material.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    required this.child,
    this.radius = 28,
    this.tint,
    this.selectedIndex,
    super.key,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final int? selectedIndex;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  MethodChannel? _channel;

  bool get _native => !kIsWeb && Platform.isIOS;

  Map<String, Object?> _configuration(BuildContext context) => {
    'radius': widget.radius,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'tint': widget.tint?.toARGB32(),
    'selectedIndex': widget.selectedIndex,
    'reduceMotion': MediaQuery.disableAnimationsOf(context),
  };

  @override
  void didUpdateWidget(covariant LiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  void _update() {
    _channel?.invokeMethod<void>('update', _configuration(context));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(widget.radius);
    final tint = widget.tint;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .20 : .10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _native
                  ? UiKitView(
                      viewType: 'com.oneupbyte.trakkar/liquid-glass',
                      creationParams: _configuration(context),
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (id) {
                        if (!mounted) return;
                        _channel = MethodChannel(
                          'com.oneupbyte.trakkar/liquid-glass/$id',
                        );
                        _update();
                      },
                    )
                  : ClipRRect(
                      borderRadius: radius,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                (tint ??
                                        (dark
                                            ? const Color(0xFF36383A)
                                            : Colors.white))
                                    .withValues(alpha: contrast ? .96 : .78),
                                (tint ??
                                        (dark
                                            ? const Color(0xFF1C1E20)
                                            : Colors.white))
                                    .withValues(alpha: contrast ? .96 : .50),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: dark ? .16 : .65,
                              ),
                              width: .75,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          if (!_native && widget.selectedIndex != null)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: AnimatedAlign(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(-1 + widget.selectedIndex! * 2 / 3, 0),
                  child: FractionallySizedBox(
                    widthFactor: .25,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .12),
                        borderRadius: radius,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class LiquidGlassTabBar extends StatelessWidget {
  const LiquidGlassTabBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['Map', 'People', 'Places', 'Settings'];
    const icons = [
      CupertinoIcons.map,
      CupertinoIcons.person_2,
      CupertinoIcons.placemark,
      CupertinoIcons.settings,
    ];
    const selectedIcons = [
      CupertinoIcons.map_fill,
      CupertinoIcons.person_2_fill,
      CupertinoIcons.placemark_fill,
      CupertinoIcons.settings_solid,
    ];
    final height =
        68.0 +
        (MediaQuery.textScalerOf(context).scale(11) - 11)
            .clamp(0.0, 22.0)
            .toDouble();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LiquidGlass(
              radius: height / 2,
              selectedIndex: currentIndex,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: currentIndex == i,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (currentIndex != i) {
                                  HapticFeedback.selectionClick();
                                }
                                onTap(i);
                              },
                              child: SizedBox.expand(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      currentIndex == i
                                          ? selectedIcons[i]
                                          : icons[i],
                                      size: 23,
                                      color: currentIndex == i
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      labels[i],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: currentIndex == i
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass is reserved for controls floating over the map; content stays solid.
class MapGlassCard extends StatelessWidget {
  const MapGlassCard({required this.child, this.elevation, super.key});
  final Widget child;
  final double? elevation;

  @override
  Widget build(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS
      ? LiquidGlass(radius: 28, child: child)
      : Card(elevation: elevation, child: child);
}
