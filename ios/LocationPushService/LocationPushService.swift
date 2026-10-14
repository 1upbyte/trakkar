import Foundation
import CoreLocation
import TrakkarLiveTrackingSDK

final class LocationPushService: NSObject, CLLocationPushServiceExtension {
  private var reporter: LocationPushReporter?
  func didReceiveLocationPushPayload(_ payload: [String: Any], completion: @escaping () -> Void) {
    Task { @MainActor in
      let reporter = LocationPushReporter()
      self.reporter = reporter
      reporter.receive(payload: payload, completion: completion)
    }
  }
  func serviceExtensionWillTerminate() {
    Task { @MainActor in reporter?.expire() }
  }
}
