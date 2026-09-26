import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/auth/qr_payload_parser.dart';
import '../../services/auth/setup_controller.dart';
import '../../widgets/server_connection_banner.dart';

typedef QrScannerBuilder = Widget Function(
  BuildContext context,
  Future<void> Function(String value) onScan,
);

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({
    required this.controller,
    this.scannerBuilder,
    super.key,
  });

  final SetupController controller;
  final QrScannerBuilder? scannerBuilder;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  final _scannerController = MobileScannerController();
  final _parser = const QrPayloadParser();
  bool _permissionReady = false;
  bool _handledCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshCameraPermission();
  }

  Future<void> _refreshCameraPermission() async {
    final granted = await Permission.camera.isGranted;
    if (mounted && granted != _permissionReady) {
      setState(() => _permissionReady = granted);
    }
  }

  Future<void> _requestCamera() async {
    if (await Permission.camera.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    final result = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _permissionReady = result.isGranted);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    await _processRawValue(raw);
  }

  Future<void> _processRawValue(String value) async {
    if (_handledCode || widget.controller.authenticationActive) return;
    String? raw = value;
    _handledCode = true;
    if (widget.scannerBuilder == null) await _scannerController.stop();
    try {
      final details = _parser.parse(raw);
      raw = null;
      await widget.controller.authenticate(details);
      if (mounted) Navigator.of(context).pop();
    } on InvalidQrPayload {
      if (!mounted) return;
      _handledCode = false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Invalid QR code'),
          content: const Text('This QR code could not be read.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startScanner();
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).pop();
                widget.controller.beginManualEntry();
              },
              child: const Text('Enter Details'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _cancelScan() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave QR scanning?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Scan Again'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enter Details'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == true) {
      Navigator.of(context).pop();
      widget.controller.beginManualEntry();
    } else if (choice == false) {
      _handledCode = false;
      await _requestAndStartScanner();
    }
  }

  Future<void> _startScanner() async {
    if (widget.scannerBuilder == null) await _scannerController.start();
  }

  Future<void> _requestAndStartScanner() async {
    await _requestCamera();
    if (_permissionReady && mounted) {
      await WidgetsBinding.instance.endOfFrame;
      await _startScanner();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan QR'),
      leading: IconButton(
        tooltip: 'Cancel scan',
        onPressed: _cancelScan,
        icon: const Icon(Icons.close),
      ),
    ),
    body: Column(
      children: [
        if (!_permissionReady)
          ServerConnectionBanner(
            message: 'Camera permission is needed to scan a QR code.',
            actionLabel: 'Re-ask',
            onAction: _requestCamera,
          ),
        Expanded(
          child: _permissionReady
              ? widget.scannerBuilder?.call(context, _processRawValue) ??
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ServerConnectionBanner(
                            message: 'Camera is unavailable. Re-ask for permission or enter details.',
                            actionLabel: 'Re-ask',
                            onAction: _requestCamera,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.controller.beginManualEntry();
                            },
                            child: const Text('Enter Details'),
                          ),
                        ],
                      ),
                    )
              : const Center(
                  child: Text(
                    'Choose Enter Details to continue without the camera.',
                  ),
                ),
        ),
        if (widget.controller.authenticationActive)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () async {
                  _handledCode = false;
                  await _requestAndStartScanner();
                },
                child: const Text('Scan Again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.controller.beginManualEntry();
                },
                child: const Text('Enter Details'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
