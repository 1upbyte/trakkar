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

The extension fixture checks one-shot form uploads and account changes during a
location request. Verify Runner's SDK cached-instance contract directly using an
SDK 1.0.11 checkout and existing Gradle caches:

```sh
python3 test/native/reproduce_sdk_singleton.py /path/to/traccar-client-sdk
```

This compiles the SDK's unmodified `sharedTracker(config)` function with its real
coroutine mutex on the JVM. Only platform bootstrap and configuration data objects
are substituted. It confirms that a second configuration leaves the cached
tracker unchanged; the separate Swift regression exercises the production reporter.

Clock cases run the production coordinator with a controllable wall clock,
continuous clock, network availability, and sleep scheduler. They exercise clock
jumps in both directions, elapsed time during suspension, and offline recovery of
a temporary profile with a deadline persisted before restart. A test-only accessor
waits for the coordinator's task; no production control flow is replaced.

Activation cases inject a registration or extension write during the actual lease
request and verify that live mode starts and later restores the baseline. They also
check that disabling during a request prevents activation, and that a push after
an explicit stop does not upload.

Verify normal and live upload cadence against the pinned SDK's unmodified
`LocationFilter` and configuration classes:

```sh
python3 test/native/verify_ios_cadence.py /path/to/traccar-client-sdk
```

This uses the Kotlin compiler dependencies in the Gradle cache. It reads both
profiles from the production Swift adapter, submits fixes once per second with
both movement and unchanged coordinates, and verifies acceptance at 600/5 seconds.
The Flutter tracker-service test separately checks the initial iOS configuration.
