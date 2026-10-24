import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/provisioning_config.dart';

class SetupQrDialog extends StatefulWidget {
  const SetupQrDialog({required this.config, super.key});

  final ProvisioningConfig config;

  @override
  State<SetupQrDialog> createState() => _SetupQrDialogState();
}

class _SetupQrDialogState extends State<SetupQrDialog> {
  final _qrKey = GlobalKey();
  bool _sharing = false;
  String? _error;

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _sharing = true;
      _error = null;
    });
    ui.Image? image;
    try {
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not render QR code');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: ['trakkar-setup.png'],
          sharePositionOrigin: origin,
        ),
      );
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Could not share the QR code. Please try again.',
        );
      }
    } finally {
      image?.dispose();
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share setup QR code'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This code includes your manager login and password. '
              'Anyone with it can access this Traccar account. '
              'Share it only with people you trust.',
            ),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _qrKey,
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox.square(
                  dimension: 240,
                  child: QrImageView(
                    data: widget.config.toSetupLink().toString(),
                    size: 240,
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Scan this code with Trakkar on the other phone.'),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sharing ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: _sharing ? null : () => _share(buttonContext),
            icon: const Icon(Icons.share_rounded),
            label: Text(_sharing ? 'Sharing…' : 'Share image'),
          ),
        ),
      ],
    );
  }
}
