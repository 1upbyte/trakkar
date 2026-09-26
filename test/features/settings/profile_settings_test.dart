import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/features/settings/profile_settings_section.dart';
import 'package:trakkar/models/user_profile.dart';

void main() {
  testWidgets('canceling image selection leaves saved image unchanged', (
    tester,
  ) async {
    var uploaded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSettingsSection(
            profile: const UserProfile(
              userId: 1,
              displayName: 'Alex',
              profileImageRef: 'server.jpg',
            ),
            isSavingName: false,
            isSavingImage: false,
            imageSelector: () async => null,
            onSaveName: (_) async => true,
            onSaveImage: (_, _) async {
              uploaded = true;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Change picture'));
    await tester.pump();
    expect(uploaded, isFalse);
    expect(find.text('Alex'), findsWidgets);
  });

  testWidgets('trims display name and reports server save result', (
    tester,
  ) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSettingsSection(
            profile: const UserProfile(userId: 1, displayName: 'Alex'),
            isSavingName: false,
            isSavingImage: false,
            onSaveName: (name) async {
              saved = name;
              return true;
            },
            onSaveImage: (_, _) async => false,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '  New name  ');
    await tester.tap(find.text('Save name'));
    await tester.pump();
    expect(saved, 'New name');
    expect(find.text('Display name updated.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('shows upload progress while the server save is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSettingsSection(
            profile: const UserProfile(userId: 1, displayName: 'Alex'),
            isSavingName: false,
            isSavingImage: true,
            onSaveName: (_) async => true,
            onSaveImage: (_, _) async => true,
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Uploading…'), findsOneWidget);
  });
}
