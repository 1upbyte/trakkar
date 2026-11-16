"""Run native policy regressions on macOS without an iOS simulator runtime.

Compiles the production Swift source, substituting only platform/SDK services,
the App Group directory, and clocks. This does not test Core Location delivery.
Run: python3 -m unittest discover -s test/native -p 'test_*.py' -v
"""

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "ios/LiveTrackingSDK/Sources/TrakkarLiveTrackingSDK"


class IOSLiveTrackingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="trakkar-native-")
        cls.addClassCleanup(cls.build.cleanup)
        directory = Path(cls.build.name)
        source = (NATIVE / "LiveTracking.swift").read_text()
        source = source.replace("import CoreLocation\n", "")
        source = source.replace("import TraccarClientSDK\n", "")
        source = source.replace(
            "FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?",
            "NativeTestRuntime.directory",
        )
        source = source.replace("Task.sleep(nanoseconds:", "NativeTestRuntime.sleep(nanoseconds:")
        source = source.replace("mach_continuous_time()", "NativeTestRuntime.continuousTicks")
        fixture = Path(__file__).with_name("ios_platform_stubs.swift").read_text()
        cases = Path(__file__).with_name("ios_live_tracking_cases.swift").read_text()
        (directory / "Regression.swift").write_text(fixture + "\n" + source + "\n" + cases)
        cls.executable = directory / "regressions"
        result = subprocess.run(
            ["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
             "-module-cache-path", str(directory / "modules"),
             str(directory / "Regression.swift"), "-o", str(cls.executable)],
            text=True, capture_output=True,
        )
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    def run_case(self, name):
        with tempfile.TemporaryDirectory(prefix="trakkar-state-") as state:
            result = subprocess.run(
                [str(self.executable), name, state],
                text=True, capture_output=True, timeout=15,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_stale_lease_write_preserves_new_registration(self):
        self.run_case("registration")

    def test_stale_extension_write_preserves_temporary_marker(self):
        self.run_case("temporary")

    def test_disabled_tracking_rejects_inflight_write(self):
        self.run_case("disabled")

    def test_successful_writer_can_save_successive_updates(self):
        self.run_case("sequential")

    def test_reused_extension_uploads_with_current_account(self):
        self.run_case("extension-account")

    def test_clock_rollback_does_not_extend_offline_lease(self):
        self.run_case("clock-backward")

    def test_clock_jump_does_not_end_lease_early(self):
        self.run_case("clock-forward")

    def test_offline_restart_does_not_trust_persisted_deadline(self):
        self.run_case("offline-restart")

    def test_suspension_counts_toward_lease_lifetime(self):
        self.run_case("clock-suspended")


if __name__ == "__main__":
    unittest.main()
