import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws the same avatar bubble the vector map shows as a widget into a PNG
/// so the native Google Maps SDK can use it as a marker icon.
class MarkerBitmapCache {
  final Map<String, BitmapDescriptor> _ready = {};
  final Set<String> _pending = {};
  final Map<int, _DecodedImage> _decoded = {};

  BitmapDescriptor? operator [](String key) => _ready[key];

  /// Starts rendering [key] if it is not cached yet. [onReady] fires once the
  /// bitmap can be used, so callers can trigger a rebuild.
  void ensure(
    String key,
    Future<BitmapDescriptor> Function() render,
    VoidCallback onReady,
  ) {
    if (_ready.containsKey(key) || _pending.contains(key)) return;
    _pending.add(key);
    unawaited(() async {
      try {
        _ready[key] = await render();
        onReady();
      } on Object catch (error) {
        debugPrint('Marker bitmap failed: $error');
      } finally {
        _pending.remove(key);
      }
    }());
  }

  /// Decodes a profile picture once per byte array.
  Future<ui.Image?> _decode(int deviceId, Uint8List? bytes) async {
    if (bytes == null) return null;
    final cached = _decoded[deviceId];
    if (cached != null && identical(cached.source, bytes)) return cached.image;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 160,
      targetHeight: 160,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    cached?.image.dispose();
    _decoded[deviceId] = _DecodedImage(bytes, frame.image);
    return frame.image;
  }

  Future<BitmapDescriptor> renderAvatar({
    required int deviceId,
    required String initial,
    required bool online,
    required bool moving,
    required double speedMph,
    required Uint8List? imageBytes,
    required ColorScheme colors,
    required double pixelRatio,
  }) async {
    final image = await _decode(deviceId, imageBytes);
    const width = 126.0;
    const height = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);

    // Avatar circle.
    const center = Offset(35 + 28, 4 + 28);
    const radius = 28.0;
    canvas.drawCircle(
      center.translate(0, 3),
      radius,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, radius, Paint()..color = colors.surface);
    final inner = radius - 3;
    if (image != null) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: inner)),
      );
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final side = src.shortestSide;
      final cover = Rect.fromCenter(
        center: src.center,
        width: side,
        height: side,
      );
      canvas.drawImageRect(
        image,
        cover,
        Rect.fromCircle(center: center, radius: inner),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(center, inner, Paint()..color = colors.primaryContainer);
      _drawText(
        canvas,
        initial,
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colors.onPrimaryContainer,
        ),
        center,
      );
    }

    // Motion badge.
    if (moving) {
      const badge = Rect.fromLTWH(86, 5, 34, 36);
      final rrect = RRect.fromRectAndRadius(badge, const Radius.circular(10));
      canvas.drawRRect(
        rrect.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawRRect(rrect, Paint()..color = colors.surface);
      _drawText(
        canvas,
        speedMph > 10 ? '🚗' : '🚶',
        const TextStyle(fontSize: 15),
        badge.center.translate(0, -7),
      );
      _drawText(
        canvas,
        '${speedMph.round()} mph',
        TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
        badge.center.translate(0, 10),
      );
    }

    // Online dot.
    const dot = Offset(78 + 7.5, height - 3 - 7.5);
    canvas.drawCircle(dot, 7.5, Paint()..color = colors.surface);
    canvas.drawCircle(
      dot,
      5.5,
      Paint()..color = online ? const Color(0xFF36A269) : Colors.grey,
    );

    return _finish(recorder, width, height, pixelRatio);
  }

  Future<BitmapDescriptor> renderPlaceIcon({
    required ColorScheme colors,
    required double pixelRatio,
  }) async {
    const size = 42.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    final icon = Icons.bookmark_rounded;
    final style = TextStyle(
      fontSize: 26,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      color: colors.tertiary,
      shadows: const [Shadow(color: Colors.white, blurRadius: 5)],
    );
    _drawText(
      canvas,
      String.fromCharCode(icon.codePoint),
      style,
      const Offset(size / 2, size / 2),
    );
    return _finish(recorder, size, size, pixelRatio);
  }

  static void _drawText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset center,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
    painter.dispose();
  }

  static Future<BitmapDescriptor> _finish(
    ui.PictureRecorder recorder,
    double width,
    double height,
    double pixelRatio,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Marker bitmap could not be encoded.');
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  void dispose() {
    for (final entry in _decoded.values) {
      entry.image.dispose();
    }
    _decoded.clear();
    _ready.clear();
  }
}

class _DecodedImage {
  const _DecodedImage(this.source, this.image);
  final Uint8List source;
  final ui.Image image;
}

/// Google Maps "night" style for the standard map in dark theme.
const googleMapsDarkStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"},{"visibility":"on"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';

/// Google Maps light style that hides business POIs, matching the Positron
/// style's quiet look.
const googleMapsLightStyle = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.attraction","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';
