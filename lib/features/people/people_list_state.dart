import '../../models/person.dart';

class PeopleListState {
  PeopleListState({
    required Iterable<PersonMapEntry> people,
    this.isLoading = false,
    this.hasError = false,
  }) : people = List.unmodifiable(_ordered(people));

  final List<PersonMapEntry> people;
  final bool isLoading;
  final bool hasError;

  static List<PersonMapEntry> _ordered(Iterable<PersonMapEntry> people) {
    final result = people.toList();
    result.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      return byName != 0 ? byName : a.personId.compareTo(b.personId);
    });
    return result;
  }
}
