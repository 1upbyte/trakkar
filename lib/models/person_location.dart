import 'package:latlong2/latlong.dart';

class PersonLocation {
  const PersonLocation({
    required this.coordinate,
    required this.fixTime,
    this.address,
    this.batteryLevel,
  });

  final LatLng coordinate;
  final DateTime? fixTime;
  final String? address;
  final double? batteryLevel;

  bool get isStale =>
      fixTime == null ||
      DateTime.now().difference(fixTime!) > const Duration(minutes: 15);
}
