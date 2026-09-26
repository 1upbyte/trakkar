import Flutter
import Foundation
import SQLite3

final class SdkConfigResetBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "trakkar/settings_reset",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(SdkConfigResetBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "clearSdkConnectionConfig" else {
      result(FlutterMethodNotImplemented)
      return
    }
    do {
      try Self.clearConfiguration(at: Self.databaseURL())
      result(nil)
    } catch {
      if case ResetDatabaseError.queuePending = error {
        result(FlutterError(
          code: "sdk_reset_queue_pending",
          message: "Pending positions must sync before reset.",
          details: nil
        ))
        return
      }
      result(FlutterError(
        code: "sdk_reset_failed",
        message: "Could not clear tracking configuration.",
        details: nil
      ))
    }
  }

  static func databaseURL() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("databases", isDirectory: true)
      .appendingPathComponent("tracker.db", isDirectory: false)
  }

  static func clearConfiguration(at databaseURL: URL) throws {
    guard FileManager.default.fileExists(atPath: databaseURL.path) else { return }
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
          let database else {
      throw ResetDatabaseError.openFailed
    }
    defer { sqlite3_close(database) }

    try execute("BEGIN IMMEDIATE", database: database)
    do {
      try verifySchema(database: database)
      let queuedBefore = try positionCount(database: database)
      guard queuedBefore == 0 else { throw ResetDatabaseError.queuePending }
      try execute("DELETE FROM Config WHERE id = 1", database: database)
      let queuedAfter = try positionCount(database: database)
      guard queuedBefore == queuedAfter else { throw ResetDatabaseError.queueChanged }
      try execute("COMMIT", database: database)
    } catch {
      try? execute("ROLLBACK", database: database)
      if case ResetDatabaseError.queuePending = error {
        throw ResetDatabaseError.queuePending
      }
      throw error
    }
  }

  private static func verifySchema(database: OpaquePointer) throws {
    let sql = "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('Config', 'Position')"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else { throw ResetDatabaseError.schemaUnavailable }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW,
          sqlite3_column_int(statement, 0) == 2 else {
      throw ResetDatabaseError.schemaUnavailable
    }
  }

  private static func positionCount(database: OpaquePointer) throws -> Int64 {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM Position", -1, &statement, nil) == SQLITE_OK,
          let statement else { throw ResetDatabaseError.schemaUnavailable }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { throw ResetDatabaseError.schemaUnavailable }
    return sqlite3_column_int64(statement, 0)
  }

  private static func execute(_ sql: String, database: OpaquePointer) throws {
    var errorMessage: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
      if let errorMessage { sqlite3_free(errorMessage) }
      throw ResetDatabaseError.queryFailed
    }
  }
}

enum ResetDatabaseError: Error {
  case openFailed
  case schemaUnavailable
  case queuePending
  case queueChanged
  case queryFailed
}
