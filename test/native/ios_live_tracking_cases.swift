import Foundation

@main
struct NativeRegressions {
  @MainActor
  static func main() async {
    do {
      var seed = LiveTrackingState(serverUrl: "https://old.test", deviceId: "old-phone")
      seed.enabled = true
      seed.deviceToken = "old-token"
      try seed.save(creating: true)
      var stale = LiveTrackingState.load()!
      var current = LiveTrackingState.load()!
      switch CommandLine.arguments[1] {
      case "disable-contention":
        NativeTestRuntime.beforeLock = {
          var latest = LiveTrackingState.load()!
          latest.deviceToken = "new-token"
          latest.expiresAt = 30_000
          try! latest.save()
        }
        try await LiveTrackingCoordinator.shared.setEnabled(false)
        guard let disabled = LiveTrackingState.load(), !disabled.enabled,
              disabled.deviceToken == "new-token", disabled.expiresAt == 0 else {
          throw Failure.message("a competing writer defeated stop or lost registration")
        }
      case "cadence-config":
        for live in [false, true] {
          let location = current.config(live: live).location
          print("CADENCE \(location.distanceMeters) \(location.intervalSeconds)")
        }
      case "activation-registration", "activation-extension", "activation-disabled":
        current.endpoint = "https://sidecar.test"
        try current.save()
        _ = try await TrackerKt.sharedTracker(config: current.config(live: false))
        NativeTestRuntime.virtualSleep = true
        NativeTestRuntime.beforeReply = {
          switch CommandLine.arguments[1] {
          case "activation-registration":
            try LiveTrackingCoordinator.shared.register(endpoint: "https://sidecar.test", token: "new-token")
          case "activation-extension":
            // Model the other process publishing its confirmed lease while the
            // main process is waiting for its own HTTP response.
            var latest = LiveTrackingState.load()!
            latest.expiresAt = 30_000
            try latest.save()
            LiveTrackingCoordinator.shared.resume()
          default:
            var latest = LiveTrackingState.load()!
            latest.enabled = false
            latest.expiresAt = 0
            try latest.save()
          }
        }
        LiveTrackingCoordinator.shared.resume()
        await LiveTrackingCoordinator.shared.waitForTestSession()
        let activated = NativeTestRuntime.profiles.contains { $0.location.accuracy == .high }
        if CommandLine.arguments[1] == "activation-disabled" {
          guard !activated, LiveTrackingState.load()?.enabled == false else {
            throw Failure.message("an in-flight lease reactivated disabled tracking")
          }
        } else {
          guard activated, TrackerKt.tracker?.config.location.accuracy == .medium else {
            throw Failure.message("a concurrent state update discarded activation or prevented restoration")
          }
          if CommandLine.arguments[1] == "activation-registration",
             LiveTrackingState.load()?.deviceToken != "new-token" {
            throw Failure.message("activation overwrote the new registration")
          }
        }
      case "registration":
        current.deviceToken = "new-token"
        try current.save()
        stale.expiresAt = 1_030_000
        do { try stale.save() } catch LiveTrackingError.stateChanged { }
        guard LiveTrackingState.load()?.deviceToken == "new-token" else {
          throw Failure.message("stale lease write overwrote the new device token")
        }
      case "temporary":
        current.temporary = true
        try current.save()
        stale.expiresAt = 1_030_000
        do { try stale.save() } catch LiveTrackingError.stateChanged { }
        guard LiveTrackingState.load()?.temporary == true else {
          throw Failure.message("stale extension write erased the live-profile recovery marker")
        }
      case "disabled":
        try await LiveTrackingCoordinator.shared.setEnabled(false)
        guard let disabled = LiveTrackingState.load(), !disabled.enabled,
              disabled.deviceToken == current.deviceToken, disabled.expiresAt == 0 else {
          throw Failure.message("stop did not persist disabled state and preserve registration")
        }
        do {
          try stale.save()
          throw Failure.message("disabled state accepted an in-flight write")
        } catch LiveTrackingError.stateChanged { }
        let reporter = LocationPushReporter()
        await withCheckedContinuation { continuation in
          reporter.receive(payload: ["type": "live_tracking"]) { continuation.resume() }
        }
        guard NativeTestRuntime.uploads.isEmpty else {
          throw Failure.message("a push uploaded a position after tracking stopped")
        }
      case "sequential":
        let revision = current.revision
        current.deviceToken = "new-token"
        try current.save()
        guard current.revision != revision else {
          throw Failure.message("successful save did not advance its revision")
        }
        current.temporary = true
        try current.save()
        guard LiveTrackingState.load()?.deviceToken == "new-token",
              LiveTrackingState.load()?.temporary == true else {
          throw Failure.message("a caller could not save successive updates")
        }
      case "extension-account", "extension-account-changed":
        // The extension process has already handled a push for the old setup.
        _ = try await TrackerKt.sharedTracker(config: seed.config(live: false))
        var replacement = LiveTrackingState(serverUrl: "https://new.test", deviceId: "new+phone & café")
        replacement.enabled = true
        replacement.endpoint = "https://sidecar.test"
        replacement.deviceToken = "new-token"
        try replacement.save(creating: true)
        NativeTestRuntime.pushFix = CLLocation()
        if CommandLine.arguments[1] == "extension-account-changed" {
          NativeTestRuntime.beforeFix = {
            var latest = LiveTrackingState.load()!
            latest.deviceToken = "replaced-token"
            try! latest.save()
          }
        }
        let reporter = LocationPushReporter()
        await withCheckedContinuation { continuation in
          reporter.receive(payload: ["type": "live_tracking"]) { continuation.resume() }
        }
        if CommandLine.arguments[1] == "extension-account-changed" {
          guard NativeTestRuntime.uploads.isEmpty else {
            throw Failure.message("extension uploaded after registration changed")
          }
        } else {
          guard NativeTestRuntime.uploads.count == 1, let upload = NativeTestRuntime.uploads.first,
                upload.url?.absoluteString == "https://new.test",
                upload.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded",
                let body = upload.httpBody,
                Set(String(decoding: body, as: UTF8.self).split(separator: "&")) == [
                  "id=new%2Bphone%20%26%20caf%C3%A9", "lat=40.0", "lon=-74.0", "timestamp=1000",
                  "accuracy=20.0", "altitude=5.0", "speed=3.89", "bearing=90.0", "batt=75", "charge=false",
                ] else {
            throw Failure.message("extension uploaded an invalid position or used the old configuration")
          }
        }
      case "offline-restart":
        current.endpoint = "https://sidecar.test"
        current.temporary = true
        current.expiresAt = 9_000_000
        try current.save()
        _ = try await TrackerKt.sharedTracker(config: current.config(live: true))
        NativeTestRuntime.virtualSleep = true
        NativeTestRuntime.networkAvailable = false
        LiveTrackingCoordinator.shared.resume()
        await LiveTrackingCoordinator.shared.waitForTestSession()
        guard TrackerKt.tracker?.config.location.accuracy == .medium,
              NativeTestRuntime.uptime == 0 else {
          throw Failure.message("offline launch reactivated a persisted lease")
        }
      case "clock-backward", "clock-forward", "clock-suspended":
        current.endpoint = "https://sidecar.test"
        try current.save()
        _ = try await TrackerKt.sharedTracker(config: current.config(live: false))
        NativeTestRuntime.virtualSleep = true
        NativeTestRuntime.wallAdjustment = CommandLine.arguments[1] == "clock-forward" ? 3_600 : -3_600
        var expectedDuration: Double = 30
        if CommandLine.arguments[1] == "clock-suspended" {
          NativeTestRuntime.suspension = 60
          NativeTestRuntime.virtualLimit = 120
          expectedDuration = 70
        }
        LiveTrackingCoordinator.shared.resume()
        await LiveTrackingCoordinator.shared.waitForTestSession()
        guard !NativeTestRuntime.continuedAfterDeadline,
              abs(NativeTestRuntime.uptime - expectedDuration) < 0.001 else {
          throw Failure.message("clock change made a 30-second lease last \(NativeTestRuntime.uptime) seconds")
        }
      default:
        throw Failure.message("unknown case")
      }
      print("PASS: \(CommandLine.arguments[1])")
    } catch {
      print("FAIL: \(error)")
      exit(1)
    }
  }
}
enum Failure: Error { case message(String) }

// The harness compiles this in the production source's file, allowing tests to
// await the coordinator's real task without changing its public interface.
extension LiveTrackingCoordinator {
  fileprivate func waitForTestSession() async {
    while let pending = task { await pending.value }
  }
}
