import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../models/saved_place.dart';
import '../../services/map/location_description.dart';
import 'people_list_state.dart';
import 'person_row.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({
    required this.state,
    required this.places,
    required this.onPersonSelected,
    required this.onRefresh,
    this.imageLoader,
    super.key,
  });

  final PeopleListState state;
  final List<SavedPlace> places;
  final ValueChanged<PersonMapEntry> onPersonSelected;
  final Future<void> Function() onRefresh;
  final Future<Uint8List> Function(String reference)? imageLoader;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.isLoading && state.people.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError && state.people.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load people.'),
            TextButton(onPressed: widget.onRefresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (state.people.isEmpty) {
      return const Center(child: Text('No people are available.'));
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        key: const PageStorageKey<String>('people-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.people.length,
        itemBuilder: (context, index) {
          final person = state.people[index];
          return PersonRow(
            person: person,
            locationDescription: _locationDescription(person),
            imageLoader: widget.imageLoader,
            onTap: () {
              if (person.position == null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Location is unavailable.')),
                  );
                return;
              }
              widget.onPersonSelected(person);
            },
          );
        },
      ),
    );
  }

  String _locationDescription(PersonMapEntry person) {
    if (person.position == null) return 'Location unavailable';
    for (final place in widget.places) {
      if (place.contains(person.position!)) return place.name;
    }
    return LocationDescription.knownDescription(person);
  }
}
