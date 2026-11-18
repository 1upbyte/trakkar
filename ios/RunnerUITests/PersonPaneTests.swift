import XCTest

final class PersonPaneTests: XCTestCase {
  private let app = XCUIApplication(bundleIdentifier: "com.oneupbyte.trakkar")

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launch()
  }

  private var pane: XCUIElement { app.otherElements["person-pane"].firstMatch }
  private var content: XCUIElement { app.otherElements["person-pane-content"].firstMatch }
  private var navigation: XCUIElement { app.otherElements["bottom-navigation"].firstMatch }
  private var action: XCUIElement { app.buttons["Give this place a friendly name"].firstMatch }

  private func waitForLayout() {
    var previous: CGRect?
    var stableSamples = 0
    let settled = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let frame = self.pane.frame
        if let previous, abs(frame.minY - previous.minY) < 0.5 {
          stableSamples += 1
        } else {
          stableSamples = 0
        }
        previous = frame
        return stableSamples >= 2
      },
      object: app
    )
    XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed)
  }

  private func checkPaneBehindNavigation(_ screenshotName: String) {
    XCTAssertTrue(pane.waitForExistence(timeout: 10))
    waitForLayout()
    XCTAssertTrue(content.exists)
    XCTAssertTrue(navigation.exists)
    XCTAssertEqual(pane.frame.maxY, app.frame.maxY, accuracy: 1,
      "The pane surface must extend to the screen bottom behind the floating menu")
    XCTAssertLessThanOrEqual(content.frame.maxY, navigation.frame.minY + 1,
      "Pane content must stay above the bottom menu")
    XCTAssertTrue(app.buttons["People"].isHittable,
      "The menu must remain above the pane and accept real iOS touches")
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = screenshotName
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func openPane() {
    let marker = app.buttons["person-marker-1"].firstMatch
    XCTAssertTrue(marker.waitForExistence(timeout: 30), app.debugDescription)
    marker.tap()
    XCTAssertTrue(pane.waitForExistence(timeout: 10))
  }

  private func dragPane(by delta: CGFloat) {
    let origin = app.coordinate(withNormalizedOffset: .zero)
    let startY = pane.frame.minY + 16
    let start = origin.withOffset(CGVector(dx: pane.frame.midX, dy: startY))
    let end = origin.withOffset(CGVector(
      dx: pane.frame.midX, dy: max(60, min(app.frame.maxY - 120, startY + delta))))
    start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
  }

  func testPaneFitsBehindMenuAndClosesWhenSwipingDownOnHandle() {
    openPane()
    checkPaneBehindNavigation("person-pane-open")
    XCTAssertTrue(action.isHittable)
    XCTAssertLessThanOrEqual(action.frame.maxY, navigation.frame.minY)

    let initialHeight = pane.frame.height
    dragPane(by: -350)
    checkPaneBehindNavigation("person-pane-after-upward-swipe")
    XCTAssertEqual(pane.frame.height, initialHeight, accuracy: 1)
    XCTAssertTrue(action.isHittable)
    XCTAssertLessThanOrEqual(action.frame.maxY, navigation.frame.minY)
    action.tap()
    XCTAssertTrue(app.staticTexts["Name this place"].waitForExistence(timeout: 5))
    app.buttons["Cancel"].tap()
    checkPaneBehindNavigation("person-pane-after-dialog")
    XCTAssertTrue(action.isHittable)
    XCTAssertLessThanOrEqual(action.frame.maxY, navigation.frame.minY)

    dragPane(by: 350)
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: pane)
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    openPane()
    checkPaneBehindNavigation("person-pane-after-swipe-and-reopen")
    app.buttons["People"].tap()
    XCTAssertTrue(app.staticTexts["1 person shared with this account"].waitForExistence(timeout: 5))
    XCTAssertFalse(pane.exists)
    app.buttons["Map"].tap()
    openPane()
    checkPaneBehindNavigation("person-pane-reopened")
  }
}
