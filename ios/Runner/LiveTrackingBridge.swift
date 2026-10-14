import CoreLocation
import Flutter
import TrakkarLiveTrackingSDK

@MainActor
final class LiveTrackingBridge: NSObject, @preconcurrency FlutterPlugin {
  private let manager = CLLocationManager()
  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = LiveTrackingBridge()
    let channel = FlutterMethodChannel(name: "trakkar/live_tracking", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(bridge, channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    Task { @MainActor in
      do {
        switch call.method {
        case "configure":
          try await LiveTrackingCoordinator.shared.configure(serverUrl: args["serverUrl"] as! String, deviceId: args["deviceId"] as! String)
          LiveTrackingCoordinator.shared.resume()
          result(nil)
        case "setEnabled":
          try await LiveTrackingCoordinator.shared.setEnabled(args["enabled"] as? Bool ?? false)
          result(nil)
        case "register":
          try LiveTrackingCoordinator.shared.register(endpoint: args["endpoint"] as! String, token: args["deviceToken"] as! String)
          result(nil)
        case "pushToken":
          guard manager.authorizationStatus == .authorizedAlways else { result(nil); return }
          manager.startMonitoringLocationPushes { data, error in
            if let data { result(data.map { String(format: "%02x", $0) }.joined()) }
            else { result(FlutterError(code: "location_push", message: "Location push registration unavailable", details: nil)) }
          }
        case "clear":
          manager.stopMonitoringLocationPushes()
          try await LiveTrackingCoordinator.shared.clear()
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "live_tracking", message: "Live tracking unavailable", details: nil))
      }
    }
  }
}
