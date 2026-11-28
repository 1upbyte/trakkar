# Local signing with a free Apple ID

Install Trakkar on your own iPhone for testing without a paid Apple Developer
account. Requires Xcode, Flutter, and a free Apple ID added in
**Xcode → Settings → Accounts**.

1. Connect and unlock the iPhone, tap **Trust**, and turn on
   **Settings → Privacy & Security → Developer Mode**.
2. Find your Personal Team ID: in Xcode → Settings → Accounts, select your
   Apple ID; the team's ID is shown next to "Personal Team" (10 characters).
3. From the repository root, run:

   ```sh
   TEAM=<your team id> ios/local-signing/install.sh --demo
   ```

   `--demo` opens with sample data and needs no server; leave it out to sign in
   to a real server. `--build-only` skips installing. With several phones
   connected, set `DEVICE=<udid>`.
4. On first launch, trust the developer profile in
   **Settings → General → VPN & Device Management**.

The script builds the same code as a normal Release build. It differs only in
signing:

- The app is built under `com.oneupbyte.trakkardev.<team id>`, because the
  official ID belongs to the paid team. It installs as a separate app with its
  own data. Set `BUNDLE_ID` to override the ID.
- Push notifications, live-tracking location pushes, and the shared App Group
  are not available, because free teams cannot sign those entitlements.
- Free installs stop opening after 7 days; rerun the script to reinstall.

The script edits `Runner.xcodeproj/project.pbxproj` during the build and
restores it when finished, so nothing tracked changes. The `--demo` flag stays
in the generated `ios/Flutter/Generated.xcconfig` until the next `flutter build`
or `flutter run`, so building the Runner scheme directly in Xcode right after
would also open in demo mode.
