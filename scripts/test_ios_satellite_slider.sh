#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# != 1 ]]; then
  echo "Usage: $0 <iOS simulator UDID>" >&2
  echo "Find a simulator with: xcrun simctl list devices available" >&2
  exit 2
fi

device="$1"
run_dir="build/slider-system-test/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run_dir"
echo "Test artifacts: $run_dir"
restore_entry_point() {
  flutter build ios --config-only --simulator --debug --target lib/main.dart \
    > "$run_dir/restore-entry-point.log" 2>&1 || {
      echo "Could not restore the normal entry point; see $run_dir/restore-entry-point.log" >&2
      return 1
    }
}
trap restore_entry_point EXIT
flutter build ios --config-only --simulator --debug --target integration_test/fixtures/map_settings_app.dart \
  > "$run_dir/flutter-build.log" 2>&1 || {
    tail -30 "$run_dir/flutter-build.log"
    exit 1
  }

xcodebuild test -workspace ios/Runner.xcworkspace -scheme SatelliteSlider \
  -configuration Debug -destination "platform=iOS Simulator,id=$device" \
  -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:RunnerUITests \
  -resultBundlePath "$run_dir/Results.xcresult" \
  CODE_SIGNING_ALLOWED=NO > "$run_dir/xcodebuild.log" 2>&1 || {
    tail -30 "$run_dir/xcodebuild.log"
    exit 1
  }
tail -12 "$run_dir/xcodebuild.log"
