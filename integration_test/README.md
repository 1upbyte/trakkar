# Person pane regression

Boot an iOS simulator, then run:

```sh
flutter drive --driver=test_driver/person_sheet.dart --target=integration_test/person_sheet_test.dart -d <simulator-id>
```

The test uses a local sample person and location without signing in. It checks
that the bottom action is visible, stays above navigation, and responds to taps
after expanding the pane and switching tabs. Screenshots are saved under
`build/person-sheet-screenshots/`.

For phone sizes and larger text in landscape, run
`flutter test test/screens/person_sheet_test.dart`.
