import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../../models/person.dart';

class PersonMarker extends StatelessWidget {
  const PersonMarker({
    required this.person,
    required this.onTap,
    this.imageLoader,
    this.size = 48,
    super.key,
  });

  final PersonMapEntry person;
  final VoidCallback onTap;
  final Future<Uint8List> Function(String uri)? imageLoader;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Show ${person.displayName}',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primaryContainer,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        clipBehavior: Clip.antiAlias,
        child: person.imageRef == null || imageLoader == null
            ? _Initials(person: person)
            : _PortraitImage(
                imageRef: person.imageRef!,
                imageLoader: imageLoader!,
                person: person,
              ),
      ),
    ),
  );
}

class _PortraitImage extends StatefulWidget {
  const _PortraitImage({
    required this.imageRef,
    required this.imageLoader,
    required this.person,
  });
  final String imageRef;
  final Future<Uint8List> Function(String uri) imageLoader;
  final PersonMapEntry person;

  @override
  State<_PortraitImage> createState() => _PortraitImageState();
}

class _PortraitImageState extends State<_PortraitImage> {
  late Future<Uint8List> _image;

  @override
  void initState() {
    super.initState();
    _image = widget.imageLoader(widget.imageRef);
  }

  @override
  void didUpdateWidget(covariant _PortraitImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageRef != widget.imageRef ||
        oldWidget.imageLoader != widget.imageLoader) {
      _image = widget.imageLoader(widget.imageRef);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) {
        return snapshot.hasError
            ? _Initials(person: widget.person)
            : const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Initials(person: widget.person),
      );
    },
  );
}

class _Initials extends StatelessWidget {
  const _Initials({required this.person});
  final PersonMapEntry person;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      person.initials,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
