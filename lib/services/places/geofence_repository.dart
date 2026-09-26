import '../../models/saved_place.dart';
import '../traccar_data_repository.dart';

abstract interface class GeofenceRepository {
  Future<List<SavedPlace>> list();
  Future<void> create({required String name, required String area});
  Future<void> delete(int id);
}

class TraccarGeofenceRepository implements GeofenceRepository {
  const TraccarGeofenceRepository(this._repository);

  final TraccarDataRepository _repository;

  @override
  Future<List<SavedPlace>> list() => _repository.loadGeofences();

  @override
  Future<void> create({required String name, required String area}) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (area.trim().isEmpty) {
      throw ArgumentError.value(area, 'area', 'must not be empty');
    }
    return _repository.createGeofence(name: trimmedName, area: area.trim());
  }

  @override
  Future<void> delete(int id) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'must be positive');
    return _repository.deleteGeofence(id);
  }
}
