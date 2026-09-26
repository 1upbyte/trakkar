import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/person.dart';

class PersonRow extends StatelessWidget {
  const PersonRow({
    required this.person,
    required this.locationDescription,
    required this.onTap,
    this.imageLoader,
    super.key,
  });

  final PersonMapEntry person;
  final String locationDescription;
  final VoidCallback onTap;
  final Future<Uint8List> Function(String reference)? imageLoader;

  @override
  Widget build(BuildContext context) {
    final stale =
        person.fixTime == null ||
        DateTime.now().difference(person.fixTime!) >
            const Duration(minutes: 15);
    return Semantics(
      button: true,
      label: '${person.displayName}, $locationDescription',
      child: ListTile(
        key: ValueKey('person-row-${person.personId}'),
        onTap: onTap,
        leading: _PersonAvatar(person: person, imageLoader: imageLoader),
        title: Text(person.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(locationDescription),
            if (stale && person.position != null)
              Text(
                person.fixTime == null
                    ? 'Last update time unavailable · Last known'
                    : 'Last known · ${person.fixTime!.toLocal()}',
              ),
          ],
        ),
        trailing: person.position == null
            ? null
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _PersonAvatar extends StatefulWidget {
  const _PersonAvatar({required this.person, this.imageLoader});
  final PersonMapEntry person;
  final Future<Uint8List> Function(String reference)? imageLoader;

  @override
  State<_PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<_PersonAvatar> {
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PersonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.imageRef != widget.person.imageRef ||
        oldWidget.imageLoader != widget.imageLoader) {
      _load();
    }
  }

  void _load() {
    final reference = widget.person.imageRef;
    final loader = widget.imageLoader;
    _image = reference == null || loader == null ? null : loader(reference);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(child: Text(widget.person.initials));
    final image = _image;
    if (image == null) return fallback;
    return FutureBuilder<Uint8List>(
      future: image,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return fallback;
        return CircleAvatar(
          backgroundImage: MemoryImage(bytes),
          onBackgroundImageError: (_, _) {},
        );
      },
    );
  }
}
