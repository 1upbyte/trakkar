import Foundation
import Darwin

// Platform boundaries only. State persistence, coordination and reporting are
// compiled from the production source by test_ios_live_tracking.py.
enum Accuracy: Equatable { case medium, high }
struct LocationConfig: Equatable {
  var accuracy: Accuracy
  var distanceMeters: Int
  var intervalSeconds: Int
  var angleDegrees: Int
  var stopDetection: Bool
  var stopTimeoutSeconds: Int
  var stationaryRadiusMeters: Int
  var heartbeatIntervalSeconds: Int
}
struct NotificationConfig: Equatable { var text: String }
struct Config: Equatable {
  var serverUrl: String
  var deviceId: String
  var location: LocationConfig
  var wakeLock: Bool
  var buffer: Bool
  var preferPlatformProviders: Bool
  var notification: NotificationConfig
}
enum AuthorizationStatus { case notDetermined, authorizedAlways }
final class CLLocationManager { var authorizationStatus = AuthorizationStatus.authorizedAlways }
final class CLServiceSession {
  enum Authorization { case always }
  init(authorization: Authorization) {}
}
final class CLBackgroundActivitySession {}
struct CLLocationUpdate {
  static func liveUpdates() -> AsyncThrowingStream<Self, Error> {
    AsyncThrowingStream { $0.finish() }
  }
}

final class Tracker {
  var config: Config
  init(config: Config) { self.config = config }
  func stop() async throws {}
  func updateConfig(newConfig: Config) async throws -> Tracker {
    let replacement = Tracker(config: newConfig)
    TrackerKt.tracker = replacement
    return replacement
  }
  func requestPosition(alarm: String?) async throws -> Bool {
    NativeTestRuntime.uploads.append(config)
    return true
  }
}
enum TrackerKt {
  static var tracker: Tracker?
  static func sharedTracker() async throws -> Tracker? { tracker }
  // SDK 1.0.11's sharedTracker(config) returns the cached instance unchanged.
  // Its contract is verified separately against the pinned Kotlin source.
  static func sharedTracker(config: Config) async throws -> Tracker {
    if let tracker { return tracker }
    let created = Tracker(config: config)
    tracker = created
    return created
  }
}

struct Date {
  var timeIntervalSince1970: Double { NativeTestRuntime.wallTime }
}
enum NativeTestRuntime {
  static var directory: URL { URL(fileURLWithPath: CommandLine.arguments[2]) }
  static var wallTime: Double = 1_000
  static var uptime: Double = 0
  static var continuousTicks: UInt64 {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    return UInt64(uptime * 1_000_000_000 * Double(timebase.denom) / Double(timebase.numer))
  }
  static var uploads: [Config] = []
  static var virtualSleep = false
  static var wallAdjustment: Double = 0
  static var networkAvailable = true
  static var continuedAfterDeadline = false
  static var suspension: Double = 0
  static var virtualLimit: Double = 40
  static func sleep(nanoseconds: UInt64) async throws {
    guard virtualSleep else {
      try await Task.sleep(nanoseconds: nanoseconds)
      return
    }
    if uptime >= 30 { continuedAfterDeadline = true }
    let seconds = Double(nanoseconds) / 1_000_000_000 + suspension
    suspension = 0
    uptime += seconds
    wallTime += seconds
    wallTime += wallAdjustment
    wallAdjustment = 0
    networkAvailable = false
    // Stop a broken coordinator deterministically instead of waiting an hour.
    if uptime >= virtualLimit { throw Failure.message("virtual time limit") }
    await Task.yield()
  }
}

// Authenticated sidecar replies; no coordinates or real network requests.
final class URLSession {
  static let shared = URLSession()
  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    guard NativeTestRuntime.networkAvailable else { throw URLError(.notConnectedToInternet) }
    let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                  httpVersion: nil, headerFields: nil)!
    return (Data("{\"expiresAt\":1030000,\"serverTime\":1000000}".utf8), response)
  }
}
