import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_profile.dart';

class ProfileSettingsSection extends StatefulWidget {
  const ProfileSettingsSection({
    required this.profile,
    required this.isSavingName,
    required this.isSavingImage,
    required this.onSaveName,
    required this.onSaveImage,
    this.imageSelector,
    this.imageLoader,
    super.key,
  });

  final UserProfile? profile;
  final bool isSavingName;
  final bool isSavingImage;
  final Future<bool> Function(String name) onSaveName;
  final Future<bool> Function(List<int> bytes, String contentType) onSaveImage;
  final Future<List<int>?> Function()? imageSelector;
  final Future<Uint8List> Function(String reference)? imageLoader;

  @override
  State<ProfileSettingsSection> createState() => _ProfileSettingsSectionState();
}

class _ProfileSettingsSectionState extends State<ProfileSettingsSection> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  Future<Uint8List>? _image;
  String? _imageRef;
  String? _successMessage;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _applyProfile();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ProfileSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.displayName != widget.profile?.displayName) {
      _nameController.text = widget.profile?.displayName ?? '';
    }
    if (oldWidget.profile?.profileImageRef != widget.profile?.profileImageRef) {
      _applyImage();
    }
  }

  void _applyProfile() {
    _nameController.text = widget.profile?.displayName ?? '';
    _applyImage();
  }

  void _applyImage() {
    _imageRef = widget.profile?.profileImageRef;
    final reference = _imageRef;
    final loader = widget.imageLoader;
    _image = reference == null || loader == null ? null : loader(reference);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    setState(() => _selectionError = null);
    try {
      final selector = widget.imageSelector;
      if (selector != null) {
        final bytes = await selector();
        if (bytes != null && mounted) {
          await _saveImage(bytes);
        }
        return;
      }
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 82,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop profile picture'),
          IOSUiSettings(title: 'Crop profile picture'),
        ],
      );
      if (cropped == null || !mounted) return;
      final bytes = await cropped.readAsBytes();
      if (!mounted) return;
      await _saveImage(bytes);
    } on Object {
      if (mounted) {
        setState(
          () => _selectionError = 'Could not select that picture. Try again.',
        );
      }
    }
  }

  Future<void> _saveImage(List<int> bytes) async {
    setState(() => _successMessage = null);
    final saved = await widget.onSaveImage(bytes, 'image/jpeg');
    if (saved && mounted) {
      setState(() => _successMessage = 'Profile picture updated.');
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _successMessage = null);
    final saved = await widget.onSaveName(name);
    if (saved && mounted) {
      setState(() => _successMessage = 'Display name updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final canEdit =
        profile != null && !widget.isSavingImage && !widget.isSavingName;
    final image = _image;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    child: image == null
                        ? Text(_initials(profile?.displayName))
                        : FutureBuilder<Uint8List>(
                            future: image,
                            builder: (context, snapshot) => snapshot.hasData
                                ? ClipOval(
                                    child: Image.memory(
                                      snapshot.data!,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(_initials(profile?.displayName)),
                          ),
                  ),
                  TextButton.icon(
                    onPressed: canEdit ? _selectImage : null,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      widget.isSavingImage ? 'Uploading…' : 'Change picture',
                    ),
                  ),
                  if (widget.isSavingImage) const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: canEdit,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: !canEdit || _nameController.text.trim().isEmpty
                    ? null
                    : _saveName,
                icon: const Icon(Icons.save_outlined),
                label: Text(widget.isSavingName ? 'Saving…' : 'Save name'),
              ),
            ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _successMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            if (_selectionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (profile == null)
              const Text('Profile details are unavailable while offline.'),
          ],
        ),
      ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}
