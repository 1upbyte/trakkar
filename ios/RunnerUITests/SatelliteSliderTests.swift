import XCTest

final class SatelliteSliderTests: XCTestCase {
  private let app = XCUIApplication(bundleIdentifier: "com.oneupbyte.trakkar")

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launch()
  }

  private var zoomLabel: XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(
        format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
        "Satellite starts at zoom ", "Satellite: "
      ))
      .firstMatch
  }

  private func revealSlider() -> XCUIElement {
    XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 30))
    let slider = app.sliders.firstMatch
    for _ in 0..<12 {
      if slider.exists {
        let frame = slider.frame
        if frame.width > 100 && frame.height > 0 && frame.minY > 80 && frame.maxY < app.frame.height - 100 {
          waitForScrollToStop(slider)
          let settled = slider.frame
          if settled.minY > 80 && settled.maxY < app.frame.height - 100 {
            return slider
          }
        }
      }
      app.swipeUp()
    }
    XCTFail("Satellite slider did not become visible")
    return slider
  }

  private func waitForScrollToStop(_ slider: XCUIElement) {
    var previousY: CGFloat?
    var stableSamples = 0
    let settled = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let y = slider.frame.midY
        if let previousY, abs(y - previousY) < 0.5 {
          stableSamples += 1
        } else {
          stableSamples = 0
        }
        previousY = y
        return stableSamples >= 2
      },
      object: app
    )
    XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed,
      "Wait for Flutter's scroll inertia before calculating native touch coordinates")
  }

  private func zoom() -> Double {
    let text = zoomLabel.label.components(separatedBy: "\n")[0]
    if text == "Satellite: never" { return 1.5 }
    if text == "Satellite: always" { return 21.5 }
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
    let currentFraction = CGFloat((zoom() - 1.5) / 20)
    // UISlider's thumb center travels within half a thumb width of each end.
    let inset: CGFloat = 16
    let frame = slider.frame
    let width = frame.width
    let origin = app.coordinate(withNormalizedOffset: .zero)
    let start = origin.withOffset(CGVector(
      dx: frame.minX + inset + (width - 2 * inset) * currentFraction, dy: frame.midY))
    // Move slightly past the track to reliably reach its exact endpoints.
    let endX = fraction <= 0 ? -40 : fraction >= 1 ? width + 40 : width * fraction
    let end = origin.withOffset(CGVector(dx: frame.minX + endX, dy: frame.midY))
    // Real UIKit touches: adjust(toNormalizedSliderPosition:) and mocked Flutter
    // callbacks bypass the gesture arbitration that caused this regression.
    start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
  }

  func testEndpointsSelectNeverAndAlwaysAndSurviveRelaunch() {
    let slider = revealSlider()
    for title in ["Satellite at street level", "Always satellite"] {
      XCTAssertFalse(app.descendants(matching: .any)
        .matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch.exists)
    }

    drag(slider, to: 0)
    waitForZoom { $0 == 1.5 }
    XCTAssertTrue(slider.isEnabled)
    XCTAssertTrue(app.staticTexts["Satellite at zoom 2: off; at zoom 21: off"].exists)
    app.terminate()
    app.launch()
    let never = revealSlider()
    XCTAssertEqual(zoom(), 1.5, "Never must survive relaunch")
    XCTAssertTrue(app.staticTexts["Satellite at zoom 2: off; at zoom 21: off"].exists)

    drag(never, to: 1)
    waitForZoom { $0 == 21.5 }
    XCTAssertTrue(never.isEnabled)
    XCTAssertTrue(app.staticTexts["Satellite at zoom 2: on; at zoom 21: on"].exists)
    app.terminate()
    app.launch()
    let always = revealSlider()
    XCTAssertEqual(zoom(), 21.5, "Always must survive relaunch")
    XCTAssertTrue(app.staticTexts["Satellite at zoom 2: on; at zoom 21: on"].exists)

    drag(always, to: 0.5)
    waitForZoom { $0 >= 2 && $0 <= 21 }
    XCTAssertTrue(app.staticTexts["Satellite at zoom 2: off; at zoom 21: on"].exists)
    XCTAssertEqual(zoom() * 2, (zoom() * 2).rounded())
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
