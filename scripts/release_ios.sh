#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  echo "Usage: $0 [build-number]"
  echo "Increment pubspec.yaml's build number, build the release, and open Xcode Organizer."
  echo "Optionally supply a higher build number if App Store Connect is ahead."
}

if [[ "${1-}" == "--help" || "${1-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script requires macOS with Xcode installed." >&2
  exit 1
fi
for tool in flutter python3 xcrun open; do
  command -v "$tool" > /dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
xcrun --find xcodebuild > /dev/null

release_version="$(python3 - "${1-}" <<'PY'
from pathlib import Path
import re
import sys

path = Path('pubspec.yaml')
text = path.read_text()
pattern = re.compile(r'^(version:[ \t]*)(\d+\.\d+\.\d+)\+(\d+)([ \t]*(?:#.*)?)$', re.MULTILINE)
matches = list(pattern.finditer(text))
if len(matches) != 1:
    sys.exit('Expected one pubspec.yaml version in the form 1.0.0+1.')
match = matches[0]
current = int(match[3])
requested = sys.argv[1]
if requested and not re.fullmatch(r'[1-9][0-9]*', requested):
    sys.exit('The build number must be a positive integer.')
number = int(requested) if requested else current + 1
if number <= current:
    sys.exit(f'The build number must be greater than {current}.')
version = f'{match[2]}+{number}'
path.write_text(text[:match.start()] + match[1] + version + match[4] + text[match.end():])
print(version)
PY
)"

echo "Building Trakkar $release_version"
if ! flutter build ipa --release --target lib/main.dart; then
  echo "Release build failed. pubspec.yaml remains at $release_version." >&2
  exit 1
fi

archive="$PWD/build/ios/archive/Runner.xcarchive"
python3 - "$archive" "$release_version" <<'PY'
from pathlib import Path
import plistlib
import sys

archive = Path(sys.argv[1])
info = archive / 'Products/Applications/Runner.app/Info.plist'
if not info.is_file():
    sys.exit(f'Release archive is missing: {info}')
with info.open('rb') as file:
    app = plistlib.load(file)
version = f"{app.get('CFBundleShortVersionString')}+{app.get('CFBundleVersion')}"
if version != sys.argv[2] or app.get('CFBundleIdentifier') != 'com.oneupbyte.trakkar':
    sys.exit(f'Archive does not match the requested Trakkar release {sys.argv[2]}.')
PY

open -a Xcode "$archive"
echo "In Organizer, choose Distribute App > App Store Connect > Upload."
echo "After processing, add the build to your TestFlight group:"
echo "https://appstoreconnect.apple.com/apps"
