import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/features/settings/server_details_section.dart';
import 'package:trakkar/models/server_details.dart';

void main() {
  testWidgets(
    'shows redacted endpoints and unavailable values without secrets',
    (tester) async {
      final details = ServerDetails.redacted(
        clientUrl: 'https://alice:password@client.example/?token=secret',
        managerUrl: 'https://manager.example/?cookie=secret',
        accountName: 'Alex',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ServerDetailsSection(details: details)),
        ),
      );
      expect(find.text('https://client.example'), findsOneWidget);
      expect(find.text('https://manager.example'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.textContaining('password'), findsNothing);
      expect(find.textContaining('secret'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ServerDetailsSection(
              details: ServerDetails(
                clientUrl: null,
                managerUrl: null,
                accountName: null,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Unavailable'), findsNWidgets(3));
    },
  );
}
