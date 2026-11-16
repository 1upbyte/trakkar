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
        let revision = current.revision
        current.enabled = false
        try current.save(expectedRevision: revision)
        do {
          try stale.save()
          throw Failure.message("disabled state accepted an in-flight write")
        } catch LiveTrackingError.stateChanged { }
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
