import XCTest

final class SatelliteSliderTests: XCTestCase {
  private let app = XCUIApplication(bundleIdentifier: "com.oneupbyte.trakkar")

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launch()
  }

  private var zoomLabel: XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "label BEGINSWITH %@", "Satellite starts at zoom "))
      .firstMatch
  }

  private func revealSlider() -> XCUIElement {
    XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 30))
    let slider = app.sliders.firstMatch
    for _ in 0..<12 {
      if slider.exists {
        let frame = slider.frame
        if frame.width > 100 && frame.height > 0 && frame.minY > 80 && frame.maxY < app.frame.height - 100 {
          return slider
        }
      }
      app.swipeUp()
    }
    XCTFail("Satellite slider did not become visible")
    return slider
  }

  private func zoom() -> Double {
    let text = zoomLabel.label.components(separatedBy: "\n")[0]
    return Double(text.replacingOccurrences(of: "Satellite starts at zoom ", with: ""))!
  }

  private func waitForZoom(_ condition: @escaping (Double) -> Bool) {
    expectation(
      for: NSPredicate { _, _ in condition(self.zoom()) },
      evaluatedWith: app,
      handler: nil
    )
    waitForExpectations(timeout: 5)
  }

  private func drag(_ slider: XCUIElement, to fraction: CGFloat) {
    let currentFraction = CGFloat((zoom() - 2) / 19)
    // UISlider's thumb center travels within half a thumb width of each end.
    let inset: CGFloat = 16
    let width = slider.frame.width
    let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
      .withOffset(CGVector(dx: inset + (width - 2 * inset) * currentFraction, dy: 0))
    let end = slider.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.5))
    // Real UIKit touches: adjust(toNormalizedSliderPosition:) and mocked Flutter
    // callbacks bypass the gesture arbitration that caused this regression.
    start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
  }

  func testSatelliteThresholdDragPersistsAndAllowsScrolling() {
    let slider = revealSlider()
    XCTAssertTrue(slider.isEnabled)
    drag(slider, to: 0.25)
    waitForZoom { $0 < 10 }
    let low = zoom()
    drag(slider, to: 0.75)
    waitForZoom { $0 > low + 5 }
    XCTAssertEqual(zoom() * 2, (zoom() * 2).rounded(), "Keep half-level steps")
    let savedLabel = zoomLabel.label

    app.terminate()
    app.launch()
    let restored = revealSlider()
    XCTAssertEqual(zoomLabel.label, savedLabel, "The threshold must survive app relaunch")

    // Scroll back toward the top: revealing the slider can reach the bottom.
    // A vertical drag starting over the slider must still scroll Settings.
    let oldY = restored.frame.midY
    restored.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(forDuration: 0.1, thenDragTo: restored.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .withOffset(CGVector(dx: 0, dy: 140)))
    XCTAssertTrue(restored.frame.isEmpty || restored.frame.midY > oldY + 40)
    XCTAssertEqual(zoomLabel.label, savedLabel)
  }
}
