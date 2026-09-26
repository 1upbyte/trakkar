import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class ManualPlaceEditor extends StatefulWidget {
  const ManualPlaceEditor({
    required this.points,
    required this.validationError,
    required this.isSaving,
    required this.onRemoveLast,
    required this.onCancel,
    required this.onSave,
    super.key,
  });

  final List<LatLng> points;
  final String? validationError;
  final bool isSaving;
  final VoidCallback onRemoveLast;
  final VoidCallback onCancel;
  final Future<void> Function(String name) onSave;

  @override
  State<ManualPlaceEditor> createState() => _ManualPlaceEditorState();
}

class _ManualPlaceEditorState extends State<ManualPlaceEditor> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      elevation: 10,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Draw a place boundary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Tap the map to add corners. Drag a corner to move it.'),
            Text('${widget.points.length} corners'),
            if (widget.validationError != null)
              Text(
                widget.validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Place name'),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.points.isEmpty ? null : widget.onRemoveLast,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo corner'),
                ),
                FilledButton(
                  onPressed:
                      widget.validationError != null ||
                          _nameController.text.trim().isEmpty ||
                          widget.isSaving
                      ? null
                      : () => widget.onSave(_nameController.text.trim()),
                  child: Text(widget.isSaving ? 'Saving…' : 'Save place'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
