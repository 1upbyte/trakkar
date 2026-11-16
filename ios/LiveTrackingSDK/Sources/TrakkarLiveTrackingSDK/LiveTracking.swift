import CoreFoundation
import CoreLocation
import Foundation
import Darwin
import TraccarClientSDK

/// Native SDK adapter shared by Runner and its location push extension.
/// All reported positions are acquired and uploaded by TraccarClientSDK.
public struct LiveTrackingState: Codable {
  public var serverUrl: String
  public var deviceId: String
  public var endpoint: String?
  public var deviceToken: String?
  public var revision = UUID().uuidString
  public var enabled = false
  public var expiresAt: Double = 0
  public var temporary = false

  public init(serverUrl: String, deviceId: String) {
    self.serverUrl = serverUrl
    self.deviceId = deviceId
  }

  public static let group = "group.com.oneupbyte.trakkar.live"
  private static var url: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
      .appendingPathComponent("live-tracking.json")
  }
  public static func load() -> Self? {
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(Self.self, from: data)
  }
  public mutating func save(creating: Bool = false, expectedRevision: String? = nil) throws {
    var saved = self
    saved.revision = UUID().uuidString
    try Self.withLock {
      guard let url = Self.url else { throw LiveTrackingError.appGroupUnavailable }
      guard creating || Self.load()?.revision == (expectedRevision ?? revision) else {
        throw LiveTrackingError.stateChanged
      }
      try JSONEncoder().encode(saved).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    // Only advance the caller's snapshot after the write succeeds. Every save
    // invalidates snapshots held across awaits or by the other process.
    self = saved
  }
  public static func clear() throws {
    try withLock {
      if let url, FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
  }
  private static func withLock<T>(_ block: () throws -> T) throws -> T {
    guard let url else { throw LiveTrackingError.appGroupUnavailable }
    let lock = url.deletingLastPathComponent().appendingPathComponent("live-tracking.lock")
    let descriptor = Darwin.open(lock.path, O_CREAT | O_RDWR, 0o600)
    guard descriptor >= 0 else { throw LiveTrackingError.appGroupUnavailable }
    defer { Darwin.close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else { throw LiveTrackingError.appGroupUnavailable }
    defer { flock(descriptor, LOCK_UN) }
    return try block()
  }

  func config(live: Bool) -> Config {
    // A positive distance makes the SDK discard intervalSeconds.
    return Config(serverUrl: serverUrl, deviceId: deviceId,
      location: LocationConfig(accuracy: live ? .high : .medium, distanceMeters: 0,
        intervalSeconds: live ? 5 : 600, angleDegrees: 0, stopDetection: !live,
        stopTimeoutSeconds: 120, stationaryRadiusMeters: 100, heartbeatIntervalSeconds: 0),
      wakeLock: false, buffer: true, preferPlatformProviders: false,
      notification: NotificationConfig(text: "Trakkar is sharing your location"))
  }

  func fetchExpiry() async -> Double? {
    guard let endpoint, let deviceToken, let base = URL(string: endpoint), base.scheme == "https",
          let url = URL(string: "\(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/v1/device-session") else { return nil }
    var request = URLRequest(url: url, timeoutInterval: 3)
    request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return 0 }
      let reply = try JSONDecoder().decode(LeaseReply.self, from: data)
      let remaining = min(30_000, max(0, reply.expiresAt - reply.serverTime))
      return Date().timeIntervalSince1970 * 1000 + remaining
    } catch { return nil }
  }
}
private struct LeaseReply: Decodable { let expiresAt: Double; let serverTime: Double }
public enum LiveTrackingError: Error { case appGroupUnavailable, stateChanged }

@MainActor
public final class LiveTrackingCoordinator {
  public static let shared = LiveTrackingCoordinator()
  private var task: Task<Void, Never>?
  private var activity: Any?
  private var authorization: Any?
  private var observing = false
  private init() {}
  public func observe() {
    guard !observing else { return }
    observing = true
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in
      Task { @MainActor in LiveTrackingCoordinator.shared.resume() }
    }, "com.oneupbyte.trakkar.live.changed" as CFString, nil, .deliverImmediately)
  }

  public func configure(serverUrl: String, deviceId: String) async throws {
    var state = LiveTrackingState.load() ?? LiveTrackingState(serverUrl: serverUrl, deviceId: deviceId)
    if state.deviceId != deviceId || state.serverUrl != serverUrl {
      state = LiveTrackingState(serverUrl: serverUrl, deviceId: deviceId)
    }
    // Flutter has just applied the normal profile. Cancel a prior native live
    // session before reconciling, so it cannot overwrite a new account/profile.
    state.temporary = false
    state.expiresAt = 0
    try state.save(creating: true)
    updateAuthorization(enabled: state.enabled)
    let previous = task
    previous?.cancel()
    await previous?.value
    if let tracker = try await TrackerKt.sharedTracker() {
      _ = try await tracker.updateConfig(newConfig: state.config(live: false))
    }
  }

  public func setEnabled(_ enabled: Bool) async throws {
    guard var state = LiveTrackingState.load() else { return }
    let revision = state.revision
    state.enabled = enabled
    if !enabled { state.expiresAt = 0 }
    try state.save(expectedRevision: revision)
    updateAuthorization(enabled: enabled)
    if enabled { resume() } else { await stop() }
  }

  public func register(endpoint: String, token: String) throws {
    guard URL(string: endpoint)?.scheme == "https", var state = LiveTrackingState.load() else { return }
    state.endpoint = endpoint
    state.deviceToken = token
    try state.save()
    resume()
  }

  /// Called at native launch, including a Core Location background launch.
  public func resume() {
    // Recreate Always authorization synchronously at background launch, before
    // SDK initialization or a network request can suspend this task.
    updateAuthorization(enabled: LiveTrackingState.load()?.enabled == true)
    guard task == nil, let state = LiveTrackingState.load(), state.enabled else { return }
    observe()
    task = Task {
      defer { task = nil; activity = nil }
      guard var state = LiveTrackingState.load(), state.enabled else { return }
      do {
        guard var tracker = try await TrackerKt.sharedTracker() else { return }
        // Repair a temporary persisted profile after process termination.
        if state.temporary {
          tracker = try await tracker.updateConfig(newConfig: state.config(live: false))
          state.temporary = false
          try state.save()
        }
        if let expiry = await state.fetchExpiry() { state.expiresAt = expiry }
        guard state.expiresAt > Date().timeIntervalSince1970 * 1000 else { return }
        guard #available(iOS 18.0, *) else { return }
        activity = CLBackgroundActivitySession()
        state.temporary = true
        try state.save()
        tracker = try await tracker.updateConfig(newConfig: state.config(live: true))
        // Core Location controls execution. The SDK remains the reporting pipeline.
        let updates = Task {
          do { for try await _ in CLLocationUpdate.liveUpdates() { if Task.isCancelled { break } } }
          catch { }
        }
        defer { updates.cancel() }
        while !Task.isCancelled {
          guard let current = LiveTrackingState.load(), current.enabled else { break }
          state = current
          let now = Date().timeIntervalSince1970 * 1000
          if state.expiresAt <= now { break }
          let sleep = min(10_000, state.expiresAt - now)
          try await Task.sleep(nanoseconds: UInt64(max(1, sleep)) * 1_000_000)
          if let expiry = await state.fetchExpiry(), var latest = LiveTrackingState.load(),
             latest.revision == state.revision {
            latest.expiresAt = expiry
            try latest.save()
          }
        }
      } catch { /* Restore the SDK profile below, including cancellation. */ }
      await restore()
    }
  }

  private func updateAuthorization(enabled: Bool) {
    guard #available(iOS 18.0, *) else { return }
    // Let the SDK own the initial permission prompt. Keep the authorization
    // session between viewer leases until tracking is explicitly stopped.
    guard enabled, CLLocationManager().authorizationStatus != .notDetermined else {
      authorization = nil
      return
    }
    if authorization == nil {
      authorization = CLServiceSession(authorization: .always)
    }
  }

  private func restore() async {
    guard var state = LiveTrackingState.load(), state.temporary else { return }
    do {
      if let tracker = try await TrackerKt.sharedTracker() {
        _ = try await tracker.updateConfig(newConfig: state.config(live: false))
      }
      state.temporary = false
      state.expiresAt = 0
      try state.save()
    } catch { /* Keep temporary=true so the next launch repairs it. */ }
  }

  private func stop() async {
    let previous = task
    previous?.cancel()
    await previous?.value
    await restore()
  }
  public func clear() async throws {
    authorization = nil
    await stop()
    try LiveTrackingState.clear()
  }
}

/// An extension has a separate SDK instance/database. Seed it with shared config,
/// keep its normal tracker stopped, and use the SDK's existing one-shot upload.
@MainActor
public final class LocationPushReporter {
  private var task: Task<Void, Never>?
  private var authorization: Any?
  public init() {}

  public func receive(payload: [String: Any], completion: @escaping () -> Void) {
    task?.cancel()
    task = Task {
      defer { authorization = nil; completion() }
      guard payload["type"] as? String == "live_tracking",
            var state = LiveTrackingState.load(), state.enabled, state.deviceToken != nil else { return }
      if #available(iOS 18.0, *) {
        authorization = CLServiceSession(authorization: .always)
      }
      // The payload is only a wake-up hint. Do not compare its server timestamp
      // with the phone's clock; fetchExpiry uses the server-relative lifetime.
      // Delayed pushes and revoked tokens cannot activate an inactive lease.
      guard let confirmed = await state.fetchExpiry(), confirmed > Date().timeIntervalSince1970 * 1000 else { return }
      state.expiresAt = confirmed
      do { try state.save() } catch { return }
      CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName("com.oneupbyte.trakkar.live.changed" as CFString), nil, nil, true)
      do {
        let cached = try await TrackerKt.sharedTracker(config: state.config(live: false))
        try await cached.stop()
        // sharedTracker(config:) reuses its singleton without applying config.
        // A reused extension process must adopt the current account explicitly.
        let tracker = try await cached.updateConfig(newConfig: state.config(live: false))
        // Start the modern location service so Core Location can hand delivery to
        // the main app. Its launch path re-creates sessions and reads the lease.
        if #available(iOS 17.0, *) {
          let handoff = Task {
            do { for try await _ in CLLocationUpdate.liveUpdates() { break } } catch { }
          }
          _ = try await tracker.requestPosition(alarm: nil)
          handoff.cancel()
        } else {
          _ = try await tracker.requestPosition(alarm: nil)
        }
      } catch { }
    }
  }
  public func expire() { task?.cancel() }
}
