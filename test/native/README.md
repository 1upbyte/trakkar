# iOS native policy regressions

Run on macOS with Xcode command-line tools:

```sh
python3 -m unittest discover -s test/native -p 'test_*.py' -v
```

The runner compiles the actual `LiveTracking.swift` source into a temporary host
executable. It substitutes the App Group directory and platform services so the
tests can run without an installed iOS simulator runtime. State serialization,
file locking, revision checks, and the coordinator/reporter implementations come
from production code. Each case runs in a separate process and temporary directory.

These tests exercise deterministic native policy; they do not establish Core
Location authorization, APNs delivery, process reuse, or background handoff on iOS.
Continue to build Runner and its extension and validate delivery on physical devices.
