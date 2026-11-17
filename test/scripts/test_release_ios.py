"""Exercise the release script without signing builds or opening applications."""

import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/release_ios.sh"


class ReleaseIOSTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="trakkar release ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        shutil.copy2(SCRIPT, self.root / "scripts/release_ios.sh")
        self.pubspec = self.root / "pubspec.yaml"
        self.original = "name: trakkar\nversion: 1.0.0+1 # Keep this comment\n"
        self.pubspec.write_text(self.original)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "python3").symlink_to(sys.executable)
        stub = self.bin / "tool.py"
        stub.write_text("""#!/usr/bin/env python3
import json, os, pathlib, plistlib, re, sys
tool = pathlib.Path(sys.argv[0]).name
with open(os.environ['RELEASE_TEST_LOG'], 'a') as log:
    log.write(json.dumps([tool, *sys.argv[1:]]) + '\\n')
if tool == 'uname':
    print('Darwin')
elif tool == 'xcrun':
    print('/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild')
elif tool == 'flutter':
    if os.environ.get('RELEASE_TEST_BUILD_FAIL'):
        sys.exit(1)
    if not os.environ.get('RELEASE_TEST_SKIP_ARCHIVE'):
        version, number = re.search(r'version: (\\S+)\\+(\\d+)', pathlib.Path('pubspec.yaml').read_text()).groups()
        info = pathlib.Path('build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Info.plist')
        info.parent.mkdir(parents=True)
        with info.open('wb') as output:
            plistlib.dump({'CFBundleShortVersionString': version, 'CFBundleVersion': number,
                          'CFBundleIdentifier': 'com.oneupbyte.trakkar'}, output)
""")
        stub.chmod(0o755)
        for tool in ["uname", "xcrun", "flutter", "open"]:
            (self.bin / tool).symlink_to(stub)
        self.log = self.root / "commands.jsonl"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        RELEASE_TEST_LOG=str(self.log))

    def run_release(self, *args, **environment):
        return subprocess.run(
            ["/bin/bash", str(self.root / "scripts/release_ios.sh"), *args],
            cwd="/tmp", env=dict(self.env, **environment),
            text=True, capture_output=True,
        )

    def calls(self, tool):
        return [call for line in self.log.read_text().splitlines()
                if (call := json.loads(line))[0] == tool]

    def test_increment_build_and_open_matching_archive(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.pubspec.read_text(), self.original.replace("+1", "+2"))
        self.assertEqual(self.calls("flutter"), [["flutter", "build", "ipa", "--release", "--target", "lib/main.dart"]])
        self.assertEqual(self.calls("open"), [["open", "-a", "Xcode", str(self.root / "build/ios/archive/Runner.xcarchive")]])
        self.assertIn("https://appstoreconnect.apple.com/apps", result.stdout)

    def test_explicit_higher_build_number(self):
        result = self.run_release("12")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("version: 1.0.0+12", self.pubspec.read_text())

    def test_reject_nonincreasing_or_invalid_build_without_changing_pubspec(self):
        for number in ["1", "0", "invalid"]:
            with self.subTest(number=number):
                result = self.run_release(number)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.pubspec.read_text(), self.original)
                self.assertEqual(self.calls("flutter"), [])
                self.assertEqual(self.calls("open"), [])

    def test_failed_build_keeps_number_and_does_not_open_xcode(self):
        result = self.run_release(RELEASE_TEST_BUILD_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("version: 1.0.0+2", self.pubspec.read_text())
        self.assertEqual(self.calls("open"), [])
        self.assertIn("Release build failed", result.stderr)

    def test_missing_archive_does_not_open_xcode(self):
        result = self.run_release(RELEASE_TEST_SKIP_ARCHIVE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("open"), [])
        self.assertIn("Release archive is missing", result.stderr)

    def test_stale_archive_does_not_open_xcode(self):
        info = self.root / "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Info.plist"
        info.parent.mkdir(parents=True)
        with info.open("wb") as output:
            plistlib.dump({"CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1",
                          "CFBundleIdentifier": "com.oneupbyte.trakkar"}, output)
        result = self.run_release(RELEASE_TEST_SKIP_ARCHIVE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("open"), [])
        self.assertIn("Archive does not match", result.stderr)


if __name__ == "__main__":
    unittest.main()
