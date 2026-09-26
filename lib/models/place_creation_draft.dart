import 'package:latlong2/latlong.dart';

enum PlaceCreationMode { auto, manual }

enum PlaceDraftStatus {
  selecting,
  loading,
  editing,
  validating,
  saving,
  failed,
  canceled,
}

class PlaceCreationDraft {
  const PlaceCreationDraft({
    required this.mode,
    this.candidateBuildingId,
    this.points = const [],
    this.name = '',
    this.status = PlaceDraftStatus.selecting,
  });

  final PlaceCreationMode mode;
  final String? candidateBuildingId;
  final List<LatLng> points;
  final String name;
  final PlaceDraftStatus status;
}
