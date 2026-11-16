"""Check actual iOS profiles against SDK 1.0.11's unmodified LocationFilter.

Usage: python3 test/native/verify_ios_cadence.py /path/to/traccar-client-sdk
Uses cached Kotlin compiler dependencies and the native Swift harness. No downloads.
"""

from pathlib import Path
import os
import subprocess
import sys
import tempfile

from reproduce_sdk_singleton import cached_jar
from test_ios_live_tracking import IOSLiveTrackingTests


def main():
    sdk = Path(sys.argv[1])
    if "/v1.0.11/" not in (sdk / "Package.swift").read_text():
        raise RuntimeError("Expected the pinned SDK 1.0.11 checkout")
    IOSLiveTrackingTests.setUpClass()
    try:
        with tempfile.TemporaryDirectory(prefix="trakkar-cadence-state-") as state:
            output = subprocess.check_output(
                [str(IOSLiveTrackingTests.executable), "cadence-config", state], text=True
            )
    finally:
        IOSLiveTrackingTests.doClassCleanups()
    profiles = [list(map(int, line.split()[1:])) for line in output.splitlines()
                if line.startswith("CADENCE ")]
    assert len(profiles) == 2
    sources = sdk / "core/src/commonMain/kotlin/org/traccar/client"
    config = (sources / "Config.kt").read_text().replace(
        "import kotlinx.serialization.Serializable", ""
    ).replace("@Serializable", "")
    # Config and LocationFilter come from the SDK. Only persistence, logging,
    # and position data are substituted; the filter's decision code is unchanged.
    fixture = """
package org.traccar.client
data class Position(val time: Long, val latitude: Double?, val longitude: Double?,
                    val bearing: Double? = null)
data class State(val paused: Boolean = false, val lastAcceptedLocation: Position? = null)
class Value(var value: State)
class StateStore {
    val state = Value(State())
    suspend fun update(transform: (State) -> State) { state.value = transform(state.value) }
}
fun interface PositionProcessor { suspend fun process(position: Position): Position? }
object Log { fun log(message: String) {} }
suspend fun main(args: Array<String>) {
    val distance = args[0].toInt()
    val seconds = args[1].toInt()
    val config = Config("https://server.test", "phone", LocationConfig(
        distanceMeters = distance, intervalSeconds = seconds, angleDegrees = 0))
    val filter = LocationFilter(config, StateStore())
    check(filter.process(Position(0, 40.0, -74.0)) != null)
    for (second in 1 until seconds) {
        // Include movement and an unchanged coordinate. Neither should bypass time.
        check(filter.process(Position(second * 1000L, 40.0 + (second % 2) * 0.001, -74.0)) == null) {
            "${seconds}s iOS profile uploaded after only ${second}s (distance=$distance)"
        }
    }
    check(filter.process(Position(seconds * 1000L, 40.001, -74.0)) != null) {
        "${seconds}s iOS profile did not upload at its deadline"
    }
    println("PASS: iOS ${seconds}s profile throttles real SDK uploads")
}
"""
    compiler = cached_jar("org.jetbrains.kotlin", "kotlin-compiler-embeddable")
    libraries = [cached_jar("org.jetbrains.kotlin", artifact) for artifact in
                 ["kotlin-stdlib", "kotlin-script-runtime", "kotlin-reflect"]]
    libraries += [cached_jar("org.jetbrains.kotlinx", "kotlinx-coroutines-core-jvm"),
                  cached_jar("org.jetbrains", "annotations")]
    classpath = os.pathsep.join(map(str, libraries))
    with tempfile.TemporaryDirectory(prefix="trakkar-sdk-cadence-") as directory:
        directory = Path(directory)
        files = []
        for name, content in [("Config.kt", config), ("LocationFilter.kt", (sources / "LocationFilter.kt").read_text()),
                              ("Cadence.kt", fixture)]:
            path = directory / name
            path.write_text(content)
            files.append(str(path))
        result = subprocess.run(
            ["java", "-cp", str(compiler) + os.pathsep + classpath,
             "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect",
             "-classpath", classpath, "-d", str(directory / "classes"), *files],
            capture_output=True, text=True,
        )
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        for profile in profiles:
            subprocess.run(["java", "-cp", str(directory / "classes") + os.pathsep + classpath,
                            "org.traccar.client.CadenceKt", *map(str, profile)], check=True)


if __name__ == "__main__":
    main()
