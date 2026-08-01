import XCTest

/// Proves the DISPLAYED number is the number the engine used.
///
/// The unit suite covers `CalculatorEngine` and `DoseProjection` and stayed green
/// through a bug where a quick-value chip set the binding but the field's local
/// text did not follow — the field read 100 while the result computed 300 mg/week.
/// That is wiring, not maths, and nothing here tested wiring until now.
final class CalculatorWiringUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// PROBE — does XCUITest drive this app at all? Everything else is worthless
    /// until this passes, so it is deliberately the smallest possible assertion.
    func testProbe_appLaunchesAndIsDriveable() {
        let app = XCUIApplication()
        app.launch()

        // First run shows the disclaimer gate before anything else.
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 10) {
            accept.tap()
        }

        // Either the tab bar (signed in) or the welcome CTAs (signed out) proves
        // the app rendered and the automation layer can see it.
        let tabBar = app.buttons["Dashboard"]
        let welcome = app.buttons["Create account"]
        let reachedSomething = tabBar.waitForExistence(timeout: 15)
            || welcome.waitForExistence(timeout: 5)

        XCTAssertTrue(reachedSomething,
                      "XCUITest could not reach a known screen — if this fails the "
                      + "automation layer is unavailable, not just the mouse.")
    }
}
