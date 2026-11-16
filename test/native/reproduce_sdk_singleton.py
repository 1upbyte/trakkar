"""Execute SDK 1.0.11's unmodified singleton function on the JVM.

Usage: python3 test/native/reproduce_sdk_singleton.py /path/to/traccar-client-sdk
Uses the Kotlin compiler and coroutine jars already present in the Gradle cache.
Only bootstrap and data objects are substituted; sharedTracker and Mutex are real.
"""

from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile


def cached_jar(group, artifact):
    root = Path.home() / ".gradle/caches/modules-2/files-2.1" / group / artifact
    jars = list(root.glob("*/*/*.jar"))
    if not jars:
        raise RuntimeError(f"No cached {artifact}; this check does not download dependencies")
    return max(jars, key=lambda path: tuple(map(int, re.findall(r"\d+", path.parents[1].name))))


def main():
    sdk = Path(sys.argv[1])
    if "/v1.0.11/" not in (sdk / "Package.swift").read_text():
        raise RuntimeError("Expected the pinned SDK 1.0.11 checkout")
    source = (sdk / "core/src/commonMain/kotlin/org/traccar/client/Tracker.kt").read_text()
    function = source.split("suspend fun sharedTracker(config: Config)", 1)[1]
    function = "suspend fun sharedTracker(config: Config)" + function.split(
        "\nprivate suspend fun bootstrap", 1
    )[0]
    kotlin = """
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
data class Config(val serverUrl: String, val deviceId: String)
data class Tracker(val config: Config)
private val sharedMutex = Mutex()
private var sharedTrackerInstance: Tracker? = null
private suspend fun bootstrap(config: Config): Tracker =
    Tracker(config).also { sharedTrackerInstance = it }
""" + function + """
fun main() = runBlocking {
    val old = Config("https://old.test", "old-phone")
    val replacement = Config("https://new.test", "new-phone")
    val first = sharedTracker(old)
    val second = sharedTracker(replacement)
    check(first === second) { "SDK no longer reuses the tracker" }
    check(second.config == old) { "SDK now applies the replacement config" }
    println("CONFIRMED: SDK sharedTracker(newConfig) retains old.test / old-phone")
}
"""
    compiler = cached_jar("org.jetbrains.kotlin", "kotlin-compiler-embeddable")
    stdlib = cached_jar("org.jetbrains.kotlin", "kotlin-stdlib")
    libraries = [stdlib, cached_jar("org.jetbrains.kotlin", "kotlin-script-runtime"),
                 cached_jar("org.jetbrains.kotlin", "kotlin-reflect"),
                 cached_jar("org.jetbrains.kotlinx", "kotlinx-coroutines-core-jvm"),
                 cached_jar("org.jetbrains", "annotations")]
    classpath = os.pathsep.join(map(str, libraries))
    with tempfile.TemporaryDirectory(prefix="trakkar-sdk-contract-") as directory:
        directory = Path(directory)
        source_file = directory / "Singleton.kt"
        source_file.write_text(kotlin)
        result = subprocess.run(
            ["java", "-cp", str(compiler) + os.pathsep + classpath,
             "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect",
             "-classpath", classpath, "-d", str(directory / "classes"), str(source_file)],
            capture_output=True, text=True,
        )
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        subprocess.run(
            ["java", "-cp", str(directory / "classes") + os.pathsep + classpath, "SingletonKt"],
            check=True,
        )


if __name__ == "__main__":
    main()
