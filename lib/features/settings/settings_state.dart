import 'package:flutter/foundation.dart';

import '../../models/map_appearance_preference.dart';
import '../../models/server_details.dart';
import '../../models/user_profile.dart';
import '../../services/settings/preferences_repository.dart';
import '../../services/settings/profile_image_repository.dart';
import '../../services/settings/settings_repository.dart';

class SettingsState extends ChangeNotifier {
  // Public dependency names keep construction readable; fields stay private.
  SettingsState({
    required ProfileRepository profileRepository,
    required ProfileImageRepository imageRepository,
    required PreferencesRepository preferences,
    required this.deviceUniqueId,
    required this.serverDetails,
  }) : _profileRepository = profileRepository,
       _imageRepository = imageRepository,
       _preferences = preferences;

  final ProfileRepository _profileRepository;
  final ProfileImageRepository _imageRepository;
  final PreferencesRepository _preferences;
  final String deviceUniqueId;
  final ServerDetails serverDetails;

  UserProfile? profile;
  MapAppearancePreference mapAppearance = const MapAppearancePreference();
  bool isLoading = true;
  bool isSavingName = false;
  bool isSavingImage = false;
  String? errorMessage;

  bool get isSaving => isSavingName || isSavingImage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final loadedProfile = await _profileRepository.loadProfile();
      profile = loadedProfile;
      try {
        final imageRef = await _imageRepository.loadImageRef(deviceUniqueId);
        profile = loadedProfile.copyWith(profileImageRef: imageRef);
      } on Object {
        // Profile editing remains available if the tracking device has not
        // appeared on the server yet.
      }
      mapAppearance = await _preferences.readMapAppearance();
    } on Object {
      errorMessage = 'Some settings could not be loaded.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDisplayName(String value) async {
    if (isSaving) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      errorMessage = 'Display name cannot be empty.';
      notifyListeners();
      return false;
    }
    isSavingName = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _profileRepository.updateDisplayName(trimmed);
      return true;
    } on Object {
      errorMessage = 'Could not save display name. Try again.';
      return false;
    } finally {
      isSavingName = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfileImage({
    required List<int> bytes,
    required String contentType,
  }) async {
    final current = profile;
    if (isSaving || current == null) return false;
    isSavingImage = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _imageRepository.upload(
        profile: current,
        deviceUniqueId: deviceUniqueId,
        bytes: bytes,
        contentType: contentType,
      );
      return true;
    } on Object {
      errorMessage = 'Could not save profile picture. Try again.';
      return false;
    } finally {
      isSavingImage = false;
      notifyListeners();
    }
  }

  Future<void> saveMapAppearance(MapAppearancePreference preference) async {
    final previous = mapAppearance;
    mapAppearance = preference;
    notifyListeners();
    try {
      await _preferences.saveMapAppearance(preference);
    } on Object {
      mapAppearance = previous;
      errorMessage = 'Could not save map appearance.';
      notifyListeners();
    }
  }

  Future<void> resetPreferences() async {
    await _preferences.reset();
    mapAppearance = const MapAppearancePreference(satelliteThresholdZoom: 19);
    notifyListeners();
  }
}
