import CoreLocation
import Flutter
import MetricKit
import UIKit
import TraccarClientSDK
import TrakkarLiveTrackingSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var locationPermissionManager: CLLocationManager?
  private var trackingSupportChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    RunnerDiagnostics.shared.start()
    LiveTrackingCoordinator.shared.onProfileChange = { live in
      RunnerDiagnostics.shared.profileChanging(live: live)
    }
    // Rebuild the persisted SDK tracker as early as possible when iOS relaunches
    // the app for a significant location change or monitored-region exit.
    Task {
      _ = try? await TrackerKt.sharedTracker()
    }
    LiveTrackingCoordinator.shared.observe()
    LiveTrackingCoordinator.shared.resume()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiquidGlass") {
      registrar.register(
        LiquidGlassFactory(messenger: registrar.messenger()),
        withId: "com.oneupbyte.trakkar/liquid-glass"
      )
      registrar.register(
        SystemControlFactory(messenger: registrar.messenger()),
        withId: "com.oneupbyte.trakkar/system-control"
      )
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveTrackingBridge") {
      LiveTrackingBridge.register(with: registrar)
    }

    let diagnostics = FlutterMethodChannel(
      name: "com.oneupbyte.trakkar/diagnostics",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    diagnostics.setMethodCallHandler { call, result in
      switch call.method {
      case "cacheDirectory": result(RunnerDiagnostics.directory.path)
      case "nativeReport": RunnerDiagnostics.shared.read(result)
      default: result(FlutterMethodNotImplemented)
      }
    }

    let channel = FlutterMethodChannel(
      name: "com.oneupbyte.trakkar/tracking-support",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async {
        switch call.method {
        case "requestAlwaysIfNeeded":
          self?.requestAlwaysLocationIfNeeded()
          result(nil)
        case "getTrackingHealth":
          let manager = CLLocationManager()
          result([
            "locationAlways": manager.authorizationStatus == .authorizedAlways,
            "locationPrecise": manager.accuracyAuthorization == .fullAccuracy,
            "activityRecognitionOkay": true,
            "batteryOptimizationOkay": true,
            "batteryOptimizationRelevant": false,
          ])
        case "openLocationSettings":
          guard let url = URL(string: UIApplication.openSettingsURLString) else {
            result(nil)
            return
          }
          UIApplication.shared.open(url)
          result(nil)
        case "openBatterySettings":
          // iOS does not expose a per-app battery-optimization exemption.
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    trackingSupportChannel = channel
  }

  private func requestAlwaysLocationIfNeeded() {
    let manager = locationPermissionManager ?? CLLocationManager()
    locationPermissionManager = manager

    // Traccar SDK handles the initial Not Determined request. This covers a
    // prior While Using choice without creating a second tracking pipeline.
    if manager.authorizationStatus == .authorizedWhenInUse {
      manager.requestAlwaysAuthorization()
    }
  }
}

// MetricKit delivers system crash diagnostics outside the crashing process run.
private final class RunnerDiagnostics: NSObject, MXMetricManagerSubscriber {
  static let shared = RunnerDiagnostics()
  static let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("trakkar-diagnostics")
  private let queue = DispatchQueue(label: "com.oneupbyte.trakkar.diagnostics", qos: .utility)
  private let retention: TimeInterval = 7 * 24 * 60 * 60

  func start() {
    MXMetricManager.shared.add(self)
    queue.async {
      _ = self.recentFile("ios-crash.log")
      _ = self.recentFile("ios-tracking.log")
    }
  }

  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    queue.async {
      guard let payload = payloads.filter({ $0.crashDiagnostics?.isEmpty == false })
        .max(by: { $0.timeStampEnd < $1.timeStampEnd }),
        let crash = payload.crashDiagnostics?.last else { return }
      let date = payload.timeStampEnd
      guard Date().timeIntervalSince(date) < self.retention else { return }
      let file = Self.directory.appendingPathComponent("ios-crash.log")
      if let existing = self.recentFile("ios-crash.log"),
         let modified = try? existing.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
         modified > date { return }
      let stack = crash.callStackTree.jsonRepresentation()
      var report = """
        iOS MetricKit crash (report window ended \(date.ISO8601Format()))
        App version \(crash.applicationVersion), signal \(crash.signal?.stringValue ?? "unknown")

        """
      let limit = 60 * 1024
      report += String(decoding: stack.prefix(limit), as: UTF8.self)
      if stack.count > limit { report += "\n[Stack excerpt capped at 60 KiB]\n" }
      self.write(report, to: file)
      try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
    }
  }

  func profileChanging(live: Bool) {
    let event = "\(Date().ISO8601Format()) iOS applying \(live ? "live" : "baseline") tracking profile\n"
    queue.async {
      let name = "ios-tracking.log"
      let previous = self.recentFile(name).flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
      let recent = (previous + event).split(separator: "\n").suffix(32)
      self.write(recent.joined(separator: "\n") + "\n", to: Self.directory.appendingPathComponent(name))
    }
  }

  func read(_ result: @escaping FlutterResult) {
    queue.async {
      let report = ["ios-tracking.log", "ios-crash.log"].compactMap {
        self.recentFile($0).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
      }.joined(separator: "\n")
      DispatchQueue.main.async { result(report) }
    }
  }

  private func recentFile(_ name: String) -> URL? {
    let file = Self.directory.appendingPathComponent(name)
    guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
      return nil
    }
    if Date().timeIntervalSince(modified) > retention {
      try? FileManager.default.removeItem(at: file)
      return nil
    }
    return file
  }

  private func write(_ report: String, to file: URL) {
    try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
    try? report.write(to: file, atomically: true, encoding: .utf8)
  }
}
