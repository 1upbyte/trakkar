import 'package:latlong2/latlong.dart';

import '../../models/person.dart';
import '../../models/saved_place.dart';
import '../traccar_data_repository.dart';

class LocationDescription {
  const LocationDescription(this.repository);

  final TraccarDataRepository repository;

  Future<String> describe(
    PersonMapEntry person,
    List<SavedPlace> places, {
    void Function()? onServerFailure,
  }) async {
    final point = person.position;
    if (point == null) return 'Location unavailable';
    for (final place in places) {
      if (place.contains(point)) return place.name;
    }
    if (person.address != null && person.address!.trim().isNotEmpty) {
      return person.address!.trim();
    }
    try {
      final address = await repository.reverseGeocode(point);
      if (address != null && address.trim().isNotEmpty) return address.trim();
    } on TraccarDataFailure {
      onServerFailure?.call();
    }
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  static String knownDescription(PersonMapEntry person) {
    final point = person.position;
    if (point == null) return 'Location unavailable';
    final address = person.address?.trim();
    if (address != null && address.isNotEmpty) return address;
    return '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';
  }

  static bool withinPlace(LatLng point, List<SavedPlace> places) =>
      places.any((place) => place.contains(point));
}
