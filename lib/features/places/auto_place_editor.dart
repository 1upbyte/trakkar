import 'package:flutter/material.dart';

import 'building_lookup.dart';

class AutoPlaceEditor extends StatefulWidget {
  const AutoPlaceEditor({
    required this.candidates,
    required this.selectedId,
    required this.isLoading,
    required this.isReviewing,
    required this.isSaving,
    required this.onSelect,
    required this.onReview,
    required this.onSearchArea,
    required this.onUseManual,
    required this.onCancel,
    required this.onSave,
    this.message,
    this.attribution = '',
    super.key,
  });

  final List<BuildingCandidate> candidates;
  final String? selectedId;
  final bool isLoading;
  final bool isReviewing;
  final bool isSaving;
  final String? message;
  final String attribution;
  final ValueChanged<BuildingCandidate> onSelect;
  final VoidCallback onReview;
  final VoidCallback onSearchArea;
  final VoidCallback onUseManual;
  final VoidCallback onCancel;
  final Future<void> Function(String name) onSave;

  @override
  State<AutoPlaceEditor> createState() => _AutoPlaceEditorState();
}

class _AutoPlaceEditorState extends State<AutoPlaceEditor> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorPanel(
    title: widget.isReviewing
        ? 'Review building boundary'
        : 'Choose a building',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isLoading) const LinearProgressIndicator(),
        if (widget.message != null) Text(widget.message!),
        if (widget.attribution.isNotEmpty)
          Text(
            'Building data: ${widget.attribution}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (widget.isReviewing) ...[
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Place name'),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text('Review the highlighted boundary before saving.'),
        ] else ...[
          const Text('Tap a building outline on the map or choose it below.'),
          if (widget.candidates.isEmpty && !widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No usable building outlines were found.'),
            ),
          if (widget.candidates.isNotEmpty)
            SizedBox(
              height: 128,
              child: ListView(
                children: [
                  for (final candidate in widget.candidates.take(8))
                    ListTile(
                      dense: true,
                      selected: widget.selectedId == candidate.id,
                      title: Text(candidate.name),
                      trailing: widget.selectedId == candidate.id
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => widget.onSelect(candidate),
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
            if (!widget.isReviewing) ...[
              OutlinedButton(
                onPressed: widget.onSearchArea,
                child: const Text('Search this area'),
              ),
              OutlinedButton(
                onPressed: widget.onUseManual,
                child: const Text('Manual'),
              ),
              FilledButton(
                onPressed: widget.selectedId == null ? null : widget.onReview,
                child: const Text('Review boundary'),
              ),
            ] else
              FilledButton(
                onPressed:
                    widget.isSaving || _nameController.text.trim().isEmpty
                    ? null
                    : () => widget.onSave(_nameController.text.trim()),
                child: Text(widget.isSaving ? 'Saving…' : 'Save place'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({required this.title, required this.child});
  final String title;
  final Widget child;

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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    ),
  );
}
