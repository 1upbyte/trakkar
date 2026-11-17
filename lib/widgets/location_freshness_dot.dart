import 'dart:async';

import 'package:flutter/material.dart';

import '../models/traccar_position.dart';

/// Indicates a recent GPS fix, independently of the device connection status.
class LocationFreshnessDot extends StatefulWidget {
  const LocationFreshnessDot({
    required this.position,
    required this.size,
    super.key,
  });

  final TraccarPosition? position;
  final double size;

  @override
  State<LocationFreshnessDot> createState() => _LocationFreshnessDotState();
}

class _LocationFreshnessDotState extends State<LocationFreshnessDot>
    with WidgetsBindingObserver {
  Timer? _expiry;
  bool _recent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateFreshness();
  }

  @override
  void didUpdateWidget(covariant LocationFreshnessDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateFreshness();
  }

  void _updateFreshness() {
    _expiry?.cancel();
    final now = DateTime.now();
    final position = widget.position;
    _recent = position?.isRecent(now: now) ?? false;
    if (_recent) {
      final expiresAt = position!.fixTime!.add(TraccarPosition.freshnessWindow);
      _expiry = Timer(expiresAt.difference(now), () {
        setState(() => _recent = false);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_updateFreshness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _recent
          ? 'Location updated within 15 seconds'
          : 'No recent location',
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _recent ? const Color(0xFF36A269) : Colors.grey,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 2,
          ),
        ),
      ),
    );
  }
}
