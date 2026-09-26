import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/people/people_list_state.dart';
import 'package:trakkar/models/person.dart';

PersonMapEntry person(String id, String name) => PersonMapEntry(
  personId: id,
  deviceId: int.parse(id),
  displayName: name,
  imageRef: null,
  position: const LatLng(35.7, -78.6),
  batteryLevel: null,
  fixTime: null,
);

void main() {
  test('includes every entry and sorts names case-insensitively', () {
    final state = PeopleListState(
      people: [person('1', 'zoe'), person('2', 'Alex'), person('3', 'morgan')],
    );
    expect(state.people.map((entry) => entry.displayName), [
      'Alex',
      'morgan',
      'zoe',
    ]);
  });

  test('new snapshots reflect updates and preserve an empty list', () {
    final previous = PeopleListState(people: [person('1', 'Morgan')]);
    final refreshed = PeopleListState(people: [person('1', 'Morgan A')]);
    expect(previous.people.single.displayName, 'Morgan');
    expect(refreshed.people.single.displayName, 'Morgan A');
    expect(PeopleListState(people: const []).people, isEmpty);
  });
}
