import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/server_details.dart';
import 'package:trakkar/models/theme_preference.dart';
import 'package:trakkar/models/user_profile.dart';

void main() {
  test('profile trims server display names and rejects missing values', () {
    final profile = UserProfile.fromTraccar({'id': 7, 'name': ' Alex '});
    expect(profile?.userId, 7);
    expect(profile?.displayName, 'Alex');
    expect(UserProfile.fromTraccar({'id': 7, 'name': '  '}), isNull);
  });

  test('server details omit user info, query parameters, and fragments', () {
    final details = ServerDetails.redacted(
      clientUrl: 'https://user:secret@track.example:443/base?token=abc#x',
      managerUrl: 'http://manager.example/path?password=secret',
      accountName: ' Alex ',
    );
    expect(details.clientUrl, 'https://track.example/base');
    expect(details.managerUrl, 'http://manager.example/path');
    expect(details.accountName, 'Alex');
    expect(
      ServerDetails.redacted(
        clientUrl: 'not a url',
        managerUrl: null,
        accountName: null,
      ).clientUrl,
      isNull,
    );
  });

  test('theme preference parses known values and defaults to system', () {
    expect(AppThemePreferenceCodec.parse('dark'), AppThemePreference.dark);
    expect(AppThemePreferenceCodec.parse('unknown'), AppThemePreference.system);
  });
}
