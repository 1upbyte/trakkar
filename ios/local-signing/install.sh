#!/bin/sh
# Builds Trakkar with a free Apple ID (Personal Team) and installs it on a
# connected iPhone. See README.md in this folder.
#
#   TEAM=<team id> ios/local-signing/install.sh [--demo] [--build-only]
#
# TEAM       Your Personal Team ID (required).
# DEVICE     iPhone UDID; defaults to the only connected physical device.
# BUNDLE_ID  App ID to build under; defaults to com.oneupbyte.trakkardev.<team>.
set -e
cd "$(dirname "$0")/.."

DEMO_DEFINE=""
BUILD_ONLY=""
for arg in "$@"; do
  case "$arg" in
    --demo) DEMO_DEFINE="--dart-define=TRAKKAR_DEMO=true" ;;
    --build-only) BUILD_ONLY=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$TEAM" ]; then
  echo "Set TEAM to your Personal Team ID (Xcode > Settings > Accounts)." >&2
  exit 2
fi
TEAM_LOWER=$(printf '%s' "$TEAM" | tr '[:upper:]' '[:lower:]')
BUNDLE_ID="${BUNDLE_ID:-com.oneupbyte.trakkardev.$TEAM_LOWER}"

if [ -z "$BUILD_ONLY" ] && [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null |
    python3 -c '
import json, sys
text = sys.stdin.read()
devices = json.loads(text[text.index("{"):])["result"]["devices"]
phones = [d["hardwareProperties"]["udid"] for d in devices
          if d["hardwareProperties"].get("reality") == "physical"
          and d["hardwareProperties"].get("platform") == "iOS"
          and d["connectionProperties"].get("pairingState") == "paired"]
print(phones[0] if len(phones) == 1 else "")
')
  if [ -z "$DEVICE" ]; then
    echo "Connect one paired iPhone, or set DEVICE to its UDID." >&2
    exit 2
  fi
fi

# --demo uses the same code, but opens with sample data and no server sign-in.
flutter build ios --release --config-only $DEMO_DEFINE

# The paid team owns com.oneupbyte.trakkar, so a free team cannot register it.
# Build under a separate ID (a separate app on the phone), then restore the
# project file so nothing tracked changes.
PBX=Runner.xcodeproj/project.pbxproj
cp "$PBX" "$PBX.local-signing-backup"
trap 'mv "$PBX.local-signing-backup" "$PBX"' EXIT
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.oneupbyte\.trakkar/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/" "$PBX"

# Free teams cannot sign push, location push, or App Group entitlements.
DERIVED="$PWD/../build/local-signing"
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_ENTITLEMENTS="$PWD/local-signing/Free.entitlements" build -quiet
APP="$DERIVED/Build/Products/Release-iphoneos/Runner.app"
echo "Built: $APP ($BUNDLE_ID)"
[ -n "$BUILD_ONLY" ] && exit 0
xcrun devicectl device install app --device "$DEVICE" "$APP"
