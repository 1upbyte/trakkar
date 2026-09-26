import 'package:flutter/material.dart';

import '../../services/auth/setup_controller.dart';
import 'qr_scan_screen.dart';

class SetupChoiceScreen extends StatelessWidget {
  const SetupChoiceScreen({required this.controller, super.key});

  final SetupController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up Trakkar')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose how to connect your account.',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Base64 is encoding, not encryption. QR codes contain your login details, so keep them private.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  controller.beginScanning();
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => QrScanScreen(controller: controller),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR'),
              ),
              OutlinedButton.icon(
                onPressed: controller.beginManualEntry,
                icon: const Icon(Icons.edit),
                label: const Text('Enter Details'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
