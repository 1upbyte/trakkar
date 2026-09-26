import 'package:latlong2/latlong.dart';

class MapViewSnapshot {
  const MapViewSnapshot({
    required this.center,
    required this.zoom,
    this.rotation = 0,
  });

  final LatLng center;
  final double zoom;
  final double rotation;
}

class MapViewState {
  const MapViewState({this.selectedPersonId, this.beforeSelection});

  final String? selectedPersonId;
  final MapViewSnapshot? beforeSelection;
}

class MapSelectionState {
  MapViewState value = const MapViewState();

  bool select(String personId, MapViewSnapshot snapshot) {
    if (value.selectedPersonId != null) return false;
    value = MapViewState(selectedPersonId: personId, beforeSelection: snapshot);
    return true;
  }

  MapViewSnapshot? restore() {
    final snapshot = value.beforeSelection;
    value = const MapViewState();
    return snapshot;
  }
}
