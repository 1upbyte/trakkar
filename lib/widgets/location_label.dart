import 'dart:async';

import 'package:flutter/material.dart';

import '../models/traccar_position.dart';

String locationFallback(TraccarPosition position) {
  final address = position.address?.trim();
  return address?.isNotEmpty == true
      ? address!
      : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
}

String positionAge(DateTime? time, {DateTime? now}) {
  if (time == null) return 'Update time unknown';
  final age = (now ?? DateTime.now()).difference(time);
  if (age.inSeconds < 60) return 'Updated just now';
  if (age.inMinutes < 60) return 'Updated ${age.inMinutes}m ago';
  if (age.inHours < 24) return 'Updated ${age.inHours}h ago';
  return 'Updated ${age.inDays}d ago';
}

class LocationLabel extends StatefulWidget {
  const LocationLabel({
    required this.position,
    this.friendlyPlace,
    this.address,
    super.key,
  });

  final TraccarPosition position;
  final String? friendlyPlace;
  final Future<String>? address;

  @override
  State<LocationLabel> createState() => _LocationLabelState();
}

class _LocationLabelState extends State<LocationLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: widget.address,
      builder: (context, snapshot) {
        final resolved =
            snapshot.hasError ||
                snapshot.connectionState != ConnectionState.done
            ? null
            : snapshot.data?.trim();
        final location =
            widget.friendlyPlace ??
            (resolved?.isNotEmpty == true
                ? resolved!
                : locationFallback(widget.position));
        return Text(
          '$location · ${positionAge(widget.position.fixTime)}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
