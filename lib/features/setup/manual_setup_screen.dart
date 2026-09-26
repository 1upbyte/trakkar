import 'package:flutter/material.dart';

import '../../models/login_details.dart';
import '../../services/auth/setup_controller.dart';

class ManualSetupScreen extends StatefulWidget {
  const ManualSetupScreen({required this.controller, super.key});

  final SetupController controller;

  @override
  State<ManualSetupScreen> createState() => _ManualSetupScreenState();
}

class _ManualSetupScreenState extends State<ManualSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _clientUrl;
  late final TextEditingController _managerUrl;

  @override
  void initState() {
    super.initState();
    final details = widget.controller.draft;
    _username = TextEditingController(text: details?.username ?? '');
    _password = TextEditingController(text: details?.password ?? '');
    _clientUrl = TextEditingController(text: details?.clientUrl ?? '');
    _managerUrl = TextEditingController(text: details?.managerUrl ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _clientUrl.dispose();
    _managerUrl.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.isEmpty ? 'Required' : null;

  LoginDetailsDraft _details() => LoginDetailsDraft(
    username: _username.text,
    password: _password.text,
    clientUrl: _clientUrl.text,
    managerUrl: _managerUrl.text,
    source: LoginSource.manual,
  );

  @override
  Widget build(BuildContext context) {
    final busy = widget.controller.authenticationActive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: busy ? null : widget.controller.abandonSetup,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: _required,
                  enabled: !busy,
                ),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: _required,
                  obscureText: true,
                  enabled: !busy,
                ),
                TextFormField(
                  controller: _clientUrl,
                  decoration: const InputDecoration(labelText: 'Client URL'),
                  validator: _required,
                  keyboardType: TextInputType.url,
                  enabled: !busy,
                ),
                TextFormField(
                  controller: _managerUrl,
                  decoration: const InputDecoration(labelText: 'Manager URL'),
                  validator: _required,
                  keyboardType: TextInputType.url,
                  enabled: !busy,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            widget.controller.authenticate(_details());
                          }
                        },
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
