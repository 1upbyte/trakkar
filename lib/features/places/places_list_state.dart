import '../../models/saved_place.dart';

class PlacesListState {
  PlacesListState({
    required Iterable<SavedPlace> places,
    this.isLoading = false,
    this.hasError = false,
  }) : places = List.unmodifiable(places);

  final List<SavedPlace> places;
  final bool isLoading;
  final bool hasError;
}
