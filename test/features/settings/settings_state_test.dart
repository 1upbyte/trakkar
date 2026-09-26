import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/features/settings/settings_state.dart';
import 'package:trakkar/models/user_profile.dart';
import 'package:trakkar/models/server_details.dart';
import 'package:trakkar/services/settings/preferences_repository.dart';
import 'package:trakkar/services/settings/profile_image_repository.dart';
import 'package:trakkar/services/settings/settings_repository.dart';

void main() {
  test(
    'commits server-confirmed profile updates and rolls back failed updates',
    () async {
      final profileRepository = _ProfileRepository();
      final imageRepository = _ImageRepository();
      final state =
          SettingsState(
              profileRepository: profileRepository,
              imageRepository: imageRepository,
              preferences: PreferencesRepository(),
              deviceUniqueId: 'device-1',
              serverDetails: const ServerDetails(
                clientUrl: null,
                managerUrl: null,
                accountName: 'Alex',
              ),
            )
            ..profile = const UserProfile(
              userId: 7,
              displayName: 'Alex',
              profileImageRef: 'old.jpg',
            );

      profileRepository.fail = true;
      expect(await state.updateDisplayName('New'), isFalse);
      expect(state.profile?.displayName, 'Alex');

      imageRepository.fail = true;
      expect(
        await state.updateProfileImage(bytes: [1], contentType: 'image/jpeg'),
        isFalse,
      );
      expect(state.profile?.profileImageRef, 'old.jpg');

      profileRepository.fail = false;
      expect(await state.updateDisplayName(' New '), isTrue);
      expect(state.profile?.displayName, 'New');
      imageRepository.fail = false;
      expect(
        await state.updateProfileImage(bytes: [1], contentType: 'image/jpeg'),
        isTrue,
      );
      expect(state.profile?.profileImageRef, 'new.jpg');
      state.dispose();
    },
  );
}

class _ProfileRepository implements ProfileRepository {
  bool fail = false;

  @override
  Future<UserProfile> loadProfile() async =>
      const UserProfile(userId: 7, displayName: 'Alex');

  @override
  Future<UserProfile> updateDisplayName(String value) async {
    if (fail) throw const SettingsRepositoryFailure();
    return UserProfile(userId: 7, displayName: value);
  }
}

class _ImageRepository implements ProfileImageRepository {
  bool fail = false;

  @override
  Future<String?> loadImageRef(String deviceUniqueId) async => null;

  @override
  Future<UserProfile> upload({
    required UserProfile profile,
    required String deviceUniqueId,
    required List<int> bytes,
    required String contentType,
  }) async {
    if (fail) throw const SettingsRepositoryFailure();
    return profile.copyWith(profileImageRef: 'new.jpg');
  }
}
