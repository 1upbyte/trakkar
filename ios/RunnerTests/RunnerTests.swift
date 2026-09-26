import Flutter
import UIKit
import XCTest
import SQLite3
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testResetFailsSafelyWhilePositionsAreQueued() throws {
    let databaseURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("db")
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(databaseURL.path, &database), SQLITE_OK)
    guard let database else { return XCTFail("Could not create test database") }
    XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE Config (id INTEGER PRIMARY KEY, json TEXT)", nil, nil, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE Position (id INTEGER PRIMARY KEY, latitude REAL)", nil, nil, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(database, "INSERT INTO Config VALUES (1, 'secret config')", nil, nil, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(database, "INSERT INTO Position VALUES (1, 35.0), (2, 36.0)", nil, nil, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_close(database), SQLITE_OK)
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    XCTAssertThrowsError(try SdkConfigResetBridge.clearConfiguration(at: databaseURL))

    var reopened: OpaquePointer?
    XCTAssertEqual(sqlite3_open(databaseURL.path, &reopened), SQLITE_OK)
    guard let reopened else { return XCTFail("Could not reopen test database") }
    defer { sqlite3_close(reopened) }
    XCTAssertEqual(try scalar(reopened, "SELECT COUNT(*) FROM Config"), 1)
    XCTAssertEqual(try scalar(reopened, "SELECT COUNT(*) FROM Position"), 2)
  }

  func testResetClearsConfigWhenQueueIsEmpty() throws {
    let databaseURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("db")
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(databaseURL.path, &database), SQLITE_OK)
    guard let database else { return XCTFail("Could not create test database") }
    XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE Config (id INTEGER PRIMARY KEY, json TEXT)", nil, nil, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE Position (id INTEGER PRIMARY KEY, latitude REAL)", nil, nil, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(database, "INSERT INTO Config VALUES (1, 'config')", nil, nil, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_close(database), SQLITE_OK)
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    try SdkConfigResetBridge.clearConfiguration(at: databaseURL)
    var reopened: OpaquePointer?
    XCTAssertEqual(sqlite3_open(databaseURL.path, &reopened), SQLITE_OK)
    guard let reopened else { return XCTFail("Could not reopen test database") }
    defer { sqlite3_close(reopened) }
    XCTAssertEqual(try scalar(reopened, "SELECT COUNT(*) FROM Config"), 0)
    XCTAssertEqual(try scalar(reopened, "SELECT COUNT(*) FROM Position"), 0)
  }

  private func scalar(_ database: OpaquePointer, _ sql: String) throws -> Int64 {
    var statement: OpaquePointer?
    XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
    guard let statement else { throw ResetDatabaseError.queryFailed }
    defer { sqlite3_finalize(statement) }
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    return sqlite3_column_int64(statement, 0)
  }

}
